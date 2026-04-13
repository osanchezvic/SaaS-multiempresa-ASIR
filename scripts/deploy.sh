#!/bin/bash
set -euo pipefail

# =====================================================
# DEPLOY DE SERVICIOS - VERSION 2.0 (REFACTORIZADA)
# =====================================================
# Desplega servicios en contenedores Docker con validaciones,
# gestión de puertos robusta, credenciales persistidas y logging.

# Cargar configuración
SCRIPT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$SCRIPT_PATH/config.env"
source "$SCRIPT_PATH/funciones/logging.sh"
source "$SCRIPT_PATH/funciones/db.sh"
source "$SCRIPT_PATH/funciones/puertos.sh"
source "$SCRIPT_PATH/funciones/utils.sh"
source "$SCRIPT_PATH/funciones/validaciones.sh"

# Parámetros
EMPRESA="${1:-}"
SERVICIO="${2:-}"

# Iniciar log
init_log "$EMPRESA" "$SERVICIO" "deploy"

# =====================================================
# VALIDACIONES DE ENTRADA
# =====================================================

if [ -z "$EMPRESA" ] || [ -z "$SERVICIO" ]; then
    log_error "Parámetros insuficientes"
    log_info "Uso: $(basename "$0") <empresa> <servicio>"
    exit 1
fi

log_info "Iniciando deploy de $EMPRESA/$SERVICIO"
log_debug "Rutas: CATALOGO=$CATALOGO_DIR, BASE=/srv/$EMPRESA"

# Validaciones pre-deploy
if ! validar_pre_deploy "$EMPRESA" "$SERVICIO"; then
    log_failed "Validaciones pre-deploy fallidas"
    exit 1
fi

# =====================================================
# COMPROBACIÓN DE EXISTENCIA
# =====================================================

SERVICIO_DIR="/srv/$EMPRESA/$SERVICIO"
COMPOSE_FILE="$SERVICIO_DIR/docker-compose.yml"

if [ -f "$COMPOSE_FILE" ]; then
    log_warn "Servicio ya existe para $EMPRESA/$SERVICIO"
    
    # Intentar obtener estado actual
    if docker compose -f "$COMPOSE_FILE" ps 2>/dev/null | grep -q "healthy\|running"; then
        log_success "Servicio ya está activo. No se realiza nueva instalación."
        exit 0
    else
        log_info "Servicio existe pero no está activo. Levantando..."
        docker compose -f "$COMPOSE_FILE" up -d
        
        if wait_container_healthy "${EMPRESA}_${SERVICIO}" 30; then
            log_success "Servicio reiniciado correctamente"
            exit 0
        else
            log_error "Error levantando servicio existente"
            exit 1
        fi
    fi
fi

# =====================================================
# PREPARAR DIRECTORIO Y CREAR BACKUP
# =====================================================

# Backup si quedaron restos de un deploy anterior fallido
if [ -d "$SERVICIO_DIR" ] && [ -n "$(ls -A "$SERVICIO_DIR" 2>/dev/null)" ]; then
    log_warn "Directorio con restos encontrado: $SERVICIO_DIR"
    if ! crear_backup "$EMPRESA" "$SERVICIO" "$SERVICIO_DIR"; then
        log_warn "No se pudo crear backup previo"
    fi
fi

mkdir -p "$SERVICIO_DIR"
log_debug "Directorio listo: $SERVICIO_DIR"

# =====================================================
# GENERAR CREDENCIALES Y VALORES
# =====================================================

log_info "Generando credenciales y valores..."

# Puerto: asignación robusta
PUERTO=$(asignar_puerto "$EMPRESA" "$SERVICIO" "dev")
if [ -z "$PUERTO" ]; then
    log_failed "No se pudo asignar puerto"
    exit 1
fi

# Credenciales
DB_NAME="${EMPRESA}_db"
DB_USER="${EMPRESA}_user"
DB_PASSWORD=$(generar_password 16)
ADMIN_USER="admin"
ADMIN_PASSWORD=$(generar_password 16)
JWT_SECRET=$(generar_token 32)

log_debug "Puerto: $PUERTO, DB: $DB_NAME, Usuario DB: $DB_USER"

# =====================================================
# GUARDAR CREDENCIALES DE FORMA SEGURA
# =====================================================

CREDENCIALES_JSON=$(jq -n \
    --arg db_name "$DB_NAME" \
    --arg db_user "$DB_USER" \
    --arg db_pass "$DB_PASSWORD" \
    --arg admin_user "$ADMIN_USER" \
    --arg admin_pass "$ADMIN_PASSWORD" \
    --arg jwt_secret "$JWT_SECRET" \
    --arg puerto "$PUERTO" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
        "db_name": $db_name,
        "db_user": $db_user,
        "db_password": $db_pass,
        "admin_user": $admin_user,
        "admin_password": $admin_pass,
        "jwt_secret": $jwt_secret,
        "puerto": $puerto,
        "created_at": $timestamp
    }')

CRED_FILE=$(guardar_credenciales "$EMPRESA" "$SERVICIO" "$CREDENCIALES_JSON")
log_success "Credenciales guardadas en $CRED_FILE"

# =====================================================
# REGISTRAR EN BASE DE DATOS
# =====================================================

if ! db_register_empresa "$EMPRESA"; then
    # Si existe, está bien
    log_debug "Empresa ya registrada"
fi

# Crear usuario admin en BD infra (si no existe)
if ! crear_usuario_admin "$EMPRESA" "$ADMIN_USER" "$ADMIN_PASSWORD"; then
    log_debug "Usuario admin ya existe o BD no disponible"
fi

if ! db_register_servicio "$EMPRESA" "$SERVICIO" "$PUERTO" "$CRED_FILE"; then
    log_error "Error registrando servicio en DB"
    exit 1
fi

# =====================================================
# GENERAR ARCHIVOS DESDE TEMPLATES
# =====================================================

log_info "Procesando templates..."

CATALOGO_SERVICIO="$CATALOGO_DIR/$SERVICIO"

# docker-compose.yml
if [ ! -f "$CATALOGO_SERVICIO/docker-compose.tpl" ]; then
    log_error "Template no encontrado: $CATALOGO_SERVICIO/docker-compose.tpl"
    exit 1
fi

sed -e "s|{{EMPRESA}}|$EMPRESA|g" \
    -e "s|{{SERVICIO}}|$SERVICIO|g" \
    -e "s|{{PUERTO}}|$PUERTO|g" \
    -e "s|{{RUTA_DATOS}}|/srv/$EMPRESA|g" \
    -e "s|{{DB_NAME}}|$DB_NAME|g" \
    -e "s|{{DB_USER}}|$DB_USER|g" \
    -e "s|{{DB_PASSWORD}}|$DB_PASSWORD|g" \
    -e "s|{{ADMIN_USER}}|$ADMIN_USER|g" \
    -e "s|{{ADMIN_PASSWORD}}|$ADMIN_PASSWORD|g" \
    -e "s|{{JWT_SECRET}}|$JWT_SECRET|g" \
    "$CATALOGO_SERVICIO/docker-compose.tpl" > "$COMPOSE_FILE"

log_debug "docker-compose.yml generado"

# .env
if [ -f "$CATALOGO_SERVICIO/env.tpl" ]; then
    sed -e "s|{{DB_NAME}}|$DB_NAME|g" \
        -e "s|{{DB_USER}}|$DB_USER|g" \
        -e "s|{{DB_PASSWORD}}|$DB_PASSWORD|g" \
        -e "s|{{ADMIN_USER}}|$ADMIN_USER|g" \
        -e "s|{{ADMIN_PASSWORD}}|$ADMIN_PASSWORD|g" \
        -e "s|{{PUERTO}}|$PUERTO|g" \
        "$CATALOGO_SERVICIO/env.tpl" > "$SERVICIO_DIR/.env"
    log_debug ".env generado"
fi

# =====================================================
# VALIDAR ARCHIVOS GENERADOS
# =====================================================

if ! validar_compose_template "$EMPRESA" "$SERVICIO"; then
    log_failed "docker-compose.yml inválido"
    exit 1
fi

if ! validar_env_template "$EMPRESA" "$SERVICIO"; then
    log_failed ".env inválido"
    exit 1
fi

# =====================================================
# CREAR RED DOCKER (si no existe)
# =====================================================

RED="${EMPRESA}_net"
if ! docker network inspect "$RED" >/dev/null 2>&1; then
    log_info "Creando red Docker: $RED"
    docker network create "$RED" --driver bridge >/dev/null
    log_debug "Red creada: $RED"
else
    log_debug "Red ya existe: $RED"
fi

# =====================================================
# DESPLEGAR EN DOCKER
# =====================================================

log_info "Desplegando en Docker..."

cd "$SERVICIO_DIR" || exit 1

if ! docker compose up -d 2>&1 | tee -a "$LOG_FILE"; then
    log_failed "Error en docker compose up"
    exit 1
fi

log_debug "docker compose up -d completado"

# =====================================================
# ESPERAR A QUE CONTENEDORES ESTÉN HEALTHY
# =====================================================

sleep 2

if ! wait_container_healthy "${EMPRESA}_${SERVICIO}" 60; then
    log_warn "Contenedor no llegó a healthy state (continuando...)"
fi

# =====================================================
# VALIDACIONES POST-DEPLOY
# =====================================================

if ! validar_post_deploy "$EMPRESA" "$SERVICIO"; then
    log_warn "Algunas validaciones post-deploy fallaron"
fi

# =====================================================
# RESUMEN FINAL
# =====================================================

LOCAL_IP=$(hostname -I | awk '{print $1}')
DASHBOARD_URL="http://$LOCAL_IP:$PUERTO"

log_info "=================================================="
log_success "DEPLOY COMPLETADO"
log_info "=================================================="
log_info "Empresa:              $EMPRESA"
log_info "Servicio:             $SERVICIO"
log_info "Puerto:               $PUERTO"
log_info "URL:                  $DASHBOARD_URL"
log_info "Red Docker:           $RED"
log_info "Directorio:           $SERVICIO_DIR"
log_info "Credenciales:         $CRED_FILE"
log_info "Logs:                 $LOG_FILE"
log_info "=================================================="
log_info ""
log_info "Credenciales (usuario DB):     $DB_USER / $DB_PASSWORD"
log_info "Credenciales (admin):          $ADMIN_USER / $ADMIN_PASSWORD"
log_info ""
log_info "Ver credenciales guardadas:    cat $CRED_FILE"
log_info "Ver logs:                      tail -f $LOG_FILE"
log_info "Ver estado:                    cd $SERVICIO_DIR && docker compose ps"
log_info "=================================================="

exit 0
