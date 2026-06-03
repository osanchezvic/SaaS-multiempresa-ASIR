#!/bin/bash

# =========================================
# DESTROY.SH - Eliminar servicios
# =========================================

exec 200>/tmp/iaas_destroy.lock
flock -n 200 || { echo "Otro proceso de destroy está en ejecución"; exit 1; }

set -euo pipefail

SCRIPT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$SCRIPT_PATH/config.env"
source "$SCRIPT_PATH/funciones/logging.sh"
source "$SCRIPT_PATH/funciones/db.sh"
source "$SCRIPT_PATH/funciones/utils.sh"

# Parámetros
EMPRESA="${1:-}"
SERVICIO="${2:-}"

# Iniciar log
init_log "$EMPRESA" "$SERVICIO" "destroy"

if [ -z "$EMPRESA" ] || [ -z "$SERVICIO" ]; then
    echo_error "Parámetros insuficientes"
    echo_info "Uso: $(basename "$0") <empresa> <servicio>"
    exit 1
fi

# Variables
SERVICIO_DIR="$DATA_DIR/$EMPRESA/$SERVICIO"
COMPOSE_FILE="$SERVICIO_DIR/docker-compose.yml"
RED="${EMPRESA}_net"
CONTAINER="${EMPRESA}_${SERVICIO}_1"

echo_info "Destruyendo servicio: $EMPRESA/$SERVICIO"
echo ""

# Confirmar acción
if ! confirmar "¿Confirma eliminar $EMPRESA/$SERVICIO? Esto hará backup antes"; then
    echo_warn "Operación cancelada"
    exit 0
fi

# Verificar que existe
if [ ! -f "$COMPOSE_FILE" ]; then
    echo_error "Servicio no encontrado: $SERVICIO_DIR"
    exit 1
fi

# Hacer backup antes de eliminar
echo_info "Haciendo backup de $EMPRESA/$SERVICIO..."
if [ -x "$SCRIPT_PATH/../infra/backups/backup.sh" ]; then
    if "$SCRIPT_PATH/../infra/backups/backup.sh" "$EMPRESA" "$SERVICIO" 2>/dev/null; then
        echo_info "Backup completado"
    else
        echo_warn "No se pudo completar backup, continuando..."
    fi
fi

# Parar y eliminar contenedores
# Mismo nombre de proyecto único que en deploy.sh para no tocar contenedores
# de otras empresas que compartan el nombre de servicio.
COMPOSE_PROJECT="${EMPRESA}_${SERVICIO}"
echo_info "Parando contenedores..."
if docker compose -p "$COMPOSE_PROJECT" -f "$COMPOSE_FILE" down 2>/dev/null; then
    echo_info "Contenedores parados"
else
    echo_warn "Error parando contenedores"
fi
# Red de seguridad: contenedores antiguos (creados antes del proyecto único)
# no llevan la etiqueta del proyecto y 'compose down' no los toca. Los
# eliminamos por nombre explícito.
docker rm -f "${EMPRESA}_${SERVICIO}" >/dev/null 2>&1 || true

# Limpiar Proxy NPM
source "$SCRIPT_PATH/funciones/npm.sh"
echo_info "Eliminando configuración de Proxy NPM..."
TOKEN=$(npm_get_token || echo "")
SUBDOMAIN="${SERVICIO}-${EMPRESA}.tensaas.es"

if [ -n "$TOKEN" ]; then
    if npm_delete_proxy "$SUBDOMAIN" "$TOKEN"; then
        echo_info "Proxy host eliminado: $SUBDOMAIN"
    else
        echo_warn "No se encontró proxy host para $SUBDOMAIN o error al eliminar"
    fi
fi

# Limpiar registro de servicios en BD
if [ -f "$DB_DIR/servicios.txt" ]; then
    grep -v "^$EMPRESA:$SERVICIO:" "$DB_DIR/servicios.txt" > "$DB_DIR/servicios.txt.tmp" || true
    mv "$DB_DIR/servicios.txt.tmp" "$DB_DIR/servicios.txt"
fi
db_unregister_servicio "$EMPRESA" "$SERVICIO"

# Eliminar datos
echo_info "Eliminando datos de $SERVICIO_DIR..."
if rm -rf "$SERVICIO_DIR" 2>/dev/null; then
    echo_info "Datos eliminados"
else
    echo_warn "No se pudieron eliminar todos los datos de $SERVICIO_DIR (posiblemente por permisos de Docker)"
    # Intentar limpiar lo básico al menos
    find "$SERVICIO_DIR" -maxdepth 1 -not -path "$SERVICIO_DIR" -exec rm -rf {} + 2>/dev/null || true
fi

# Limpiar credenciales
CRED_FILE="$CREDENTIALS_DIR/${EMPRESA}.${SERVICIO}"
if [ -f "$CRED_FILE" ]; then
    rm -f "$CRED_FILE"
    echo_info "Credenciales eliminadas"
fi

echo ""
echo_info "Servicio $EMPRESA/$SERVICIO eliminado correctamente"
echo_debug "Log: $(ls -t scripts/logs/*destroy*.log 2>/dev/null | head -1)"
