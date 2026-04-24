#!/bin/bash

# =========================================
# LOGGING SIMPLE (COLOREADO)
# =========================================

echo_info() {
    echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $*"
}

echo_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

echo_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"
}

echo_debug() {
    if [ "${DEBUG:-0}" -eq 1 ]; then
        echo "[DEBUG] $*"
    fi
}

echo_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"
}

# Alias para compatibilidad
log_info() { echo_info "$@"; }
log_error() { echo_error "$@"; }
log_warn() { echo_warn "$@"; }
log_debug() { echo_debug "$@"; }
log_success() { echo_success "$@"; }
log_failed() { echo_error "$@"; }

# Inicializar log (crear directorio si no existe)
init_log() {
    local empresa="${1:-generic}"
    local servicio="${2:-generic}"
    local operacion="${3:-operation}"
    
    mkdir -p "$LOG_DIR"
}

# Función para esperar contenedor healthy
wait_container_healthy() {
    local container="$1"
    local timeout="${2:-60}"
    local start_time=$(date +%s)
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            return 1
        fi
        
        if [ "$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null)" == "true" ]; then
            return 0
        fi
        
        sleep 2
    done
}

export -f echo_info echo_error echo_warn echo_debug echo_success
export -f log_info log_error log_warn log_debug log_success log_failed
export -f init_log wait_container_healthy
