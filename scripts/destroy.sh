#!/bin/bash

# =========================================
# DESTROY.SH - Eliminar servicios
# =========================================

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
    echo_error "Parametros insuficientes"
    echo_info "Uso: $(basename "$0") <empresa> <servicio>"
    exit 1
fi

# Variables
SERVICIO_DIR="/srv/$EMPRESA/$SERVICIO"
COMPOSE_FILE="$SERVICIO_DIR/docker-compose.yml"
RED="${EMPRESA}_net"
CONTAINER="${EMPRESA}_${SERVICIO}_1"

echo_info "Destruyendo servicio: $EMPRESA/$SERVICIO"
echo ""

# Confirmar acción
if ! confirmar "Confirma eliminar $EMPRESA/$SERVICIO? Esto hará backup antes"; then
    echo_warn "Operacion cancelada"
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
echo_info "Parando contenedores..."
if docker compose -f "$COMPOSE_FILE" down 2>/dev/null; then
    echo_info "Contenedores parados"
else
    echo_warn "Error parando contenedores"
fi

# Eliminar datos
echo_info "Eliminando datos de $SERVICIO_DIR..."
if rm -rf "$SERVICIO_DIR"; then
    echo_info "Datos eliminados"
else
    echo_error "Error al eliminar datos"
    exit 1
fi

# Eliminar red si está vacía
if docker network inspect "$RED" >/dev/null 2>&1; then
    NUM_CONT=$(docker network inspect "$RED" -f '{{len .Containers}}' 2>/dev/null || echo 0)
    if [ "$NUM_CONT" -eq 0 ]; then
        echo_info "Eliminando red: $RED"
        docker network rm "$RED" 2>/dev/null || echo_warn "No se pudo eliminar red"
    fi
fi

# Limpiar registro de servicios en BD
if [ -f "$DB_DIR/servicios.txt" ]; then
    grep -v "^$EMPRESA:$SERVICIO:" "$DB_DIR/servicios.txt" > "$DB_DIR/servicios.txt.tmp" || true
    mv "$DB_DIR/servicios.txt.tmp" "$DB_DIR/servicios.txt"
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
