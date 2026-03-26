#!/bin/bash

# =========================================
# GET-CREDENTIALS.SH - Mostrar credenciales
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

if [ -z "$EMPRESA" ] || [ -z "$SERVICIO" ]; then
    echo_error "Parametros insuficientes"
    echo_info "Uso: $(basename "$0") <empresa> <servicio>"
    exit 1
fi

# Verificar que servicio existe
if ! servicio_existe "$EMPRESA" "$SERVICIO"; then
    echo_error "Servicio no encontrado: $EMPRESA/$SERVICIO"
    exit 1
fi

# Archivo de credenciales
CRED_FILE="$CREDENTIALS_DIR/${EMPRESA}.${SERVICIO}"

if [ ! -f "$CRED_FILE" ]; then
    echo_error "Credenciales no encontradas para $EMPRESA/$SERVICIO"
    echo_info "Archivo esperado: $CRED_FILE"
    exit 1
fi

echo_info "Credenciales de $EMPRESA/$SERVICIO:"
echo ""
echo "===================================================="

while IFS== read -r key value; do
    if [ -n "$key" ]; then
        printf "%-20 : %s\n" "$key" "$value"
    fi
done < "$CRED_FILE"

echo "===================================================="
echo ""
echo_debug "Archivo: $CRED_FILE"
