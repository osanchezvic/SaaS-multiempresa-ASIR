#!/bin/bash
set -euo pipefail

# =====================================================
# SYNC.SH - Reconciliación del registro con la realidad
# =====================================================
# Cruza servicios.txt con el estado real de Docker:
#   - running  -> mantiene la línea como :running   (BD: activo)
#   - parado   -> mantiene la línea como :stopped   (BD: inactivo)
#   - no existe-> BORRA la línea                     (BD: eliminado)
#
# Variables:
#   DRY_RUN=true   -> solo muestra qué haría, sin escribir nada
#
# Pensado para ejecutarse a mano o por cron.
# =====================================================

SCRIPT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$SCRIPT_PATH/config.env"
source "$SCRIPT_PATH/funciones/logging.sh"
source "$SCRIPT_PATH/funciones/db.sh"

DRY_RUN="${DRY_RUN:-false}"

# Wrapper: en dry-run no se escribe en la BD
set_estado_bd() {
    [ "$DRY_RUN" = "true" ] && return 0
    db_set_servicio_estado "$@"
}

# Bloqueo: no reconciliar mientras hay un deploy/destroy en curso
exec 200>/tmp/iaas_sync.lock
if ! flock -n 200; then
    echo_warn "Otro proceso (sync) ya está en ejecución, abortando"
    exit 0
fi

SERVICIOS_FILE="$DB_DIR/servicios.txt"
if [ ! -f "$SERVICIOS_FILE" ]; then
    echo_warn "No existe $SERVICIOS_FILE, nada que reconciliar"
    exit 0
fi

# Snapshot único del estado de Docker (evita llamar a docker por cada línea)
RUNNING=$(docker ps    --format '{{.Names}}' 2>/dev/null || true)
ALL=$(    docker ps -a --format '{{.Names}}' 2>/dev/null || true)

# Estado real de un servicio -> running | stopped | missing
# Normaliza guiones a guiones bajos (ej: uptime-kuma -> uptime_kuma)
estado_real() {
    local empresa="$1" servicio="$2"
    local variantes=("${empresa}_${servicio}" "${empresa}_${servicio//-/_}")
    local c
    for c in "${variantes[@]}"; do
        grep -qx "$c" <<< "$RUNNING" && { echo "running"; return; }
    done
    for c in "${variantes[@]}"; do
        grep -qx "$c" <<< "$ALL" && { echo "stopped"; return; }
    done
    echo "missing"
}

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

n_running=0; n_stopped=0; n_removed=0; n_total=0

echo_info "Reconciliando $SERVICIOS_FILE con el estado real de Docker..."
[ "$DRY_RUN" = "true" ] && echo_warn "MODO DRY-RUN: no se escribirá nada"

while IFS=: read -r empresa servicio puerto estado_txt; do
    # Saltar líneas vacías o malformadas
    [ -z "${empresa:-}" ] && continue
    [ -z "${servicio:-}" ] && continue
    n_total=$((n_total + 1))

    real=$(estado_real "$empresa" "$servicio")

    case "$real" in
        running)
            echo "${empresa}:${servicio}:${puerto}:running" >> "$TMP_FILE"
            set_estado_bd "$empresa" "$servicio" "activo"
            n_running=$((n_running + 1))
            echo_debug "RUNNING  ${empresa}/${servicio}"
            ;;
        stopped)
            echo "${empresa}:${servicio}:${puerto}:stopped" >> "$TMP_FILE"
            set_estado_bd "$empresa" "$servicio" "inactivo"
            n_stopped=$((n_stopped + 1))
            echo_warn "STOPPED  ${empresa}/${servicio} (existe pero no corre)"
            ;;
        missing)
            set_estado_bd "$empresa" "$servicio" "eliminado"
            n_removed=$((n_removed + 1))
            echo_error "BORRADO  ${empresa}/${servicio} (contenedor inexistente) -> fuera del registro"
            ;;
    esac
done < "$SERVICIOS_FILE"

# Aviso de drift inverso: contenedores tenant que corren pero NO están registrados.
# Precalculamos el conjunto de nombres registrados (normalizados) para evitar
# pipes anidados con grep -q (que provocan SIGPIPE y falsos positivos bajo pipefail).
INFRA_RE='^(infra_|npm_|nginx_proxy|alertmanager|portainer_global|prometheus_global|node_exporter|grafana_global|cloudflared|redis$|authelia|watchtower|dashy|landing|portfolio|fail2ban)'
REGISTRADOS=$(while IFS=: read -r e s _ _; do
    [ -z "${e:-}" ] && continue
    echo "${e}_${s}"
    echo "${e}_${s//-/_}"
done < "$TMP_FILE")

while read -r cont; do
    [ -z "$cont" ] && continue
    if grep -qE "$INFRA_RE" <<< "$cont"; then continue; fi
    if ! grep -qxF "$cont" <<< "$REGISTRADOS"; then
        echo_warn "SIN REGISTRAR: contenedor '$cont' corre pero no está en servicios.txt"
    fi
done <<< "$RUNNING"

# Escribir resultado
if [ "$DRY_RUN" = "true" ]; then
    echo_info "DRY-RUN: resultado que se escribiría:"
    cat "$TMP_FILE"
else
    cp "$SERVICIOS_FILE" "${SERVICIOS_FILE}.bak"
    mv "$TMP_FILE" "$SERVICIOS_FILE"
    trap - EXIT
fi

echo ""
echo_success "Reconciliación completada"
echo_info "Total analizados: $n_total | running: $n_running | stopped: $n_stopped | borrados: $n_removed"
if [ "$DRY_RUN" != "true" ]; then
    echo_info "Backup previo: ${SERVICIOS_FILE}.bak"
fi

exit 0
