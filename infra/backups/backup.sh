#!/bin/bash

# =========================================
# BACKUP.SH - Hacer backup de servicios
# =========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

# Funciones básicas
backup_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$BACKUP_LOG"
}

# Validar parámetros
if [ $# -lt 2 ]; then
    echo "Uso: $0 <empresa> <servicio>"
    echo "Ej:  $0 acme wordpress"
    exit 1
fi

EMPRESA="$1"
SERVICIO="$2"
CONTAINER="${EMPRESA}_${SERVICIO}_1"

# Crear directorios
mkdir -p "$BACKUP_BASE_DIR/$EMPRESA/$SERVICIO"

# Verificar que contenedor existe
if ! docker ps -a | grep -q "$CONTAINER"; then
    echo "[ERROR] Contenedor no encontrado: $CONTAINER"
    backup_log "FAIL: Contenedor $CONTAINER no existe"
    exit 1
fi

# Generar nombre backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_BASE_DIR/$EMPRESA/$SERVICIO/backup_${TIMESTAMP}.tar.gz"

echo "[INFO] Iniciando backup: $EMPRESA/$SERVICIO"

# Obtener volumes del contenedor
VOLUMES=$(docker inspect "$CONTAINER" | grep -o '"/var/lib/docker/volumes/[^"]*/_data"' 2>/dev/null | sed 's|"/var/lib/docker/volumes/||g' | sed 's|/_data"||g')

if [ -z "$VOLUMES" ]; then
    echo "[WARN] Sin volúmenes encontrados para $CONTAINER"
    BACKUP_FILE="${BACKUP_FILE%.tar.gz}_empty.tar.gz"
fi

# Crear backup (volúmenes + config)
TEMP_BACKUP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_BACKUP_DIR"' EXIT

{
    # Exportar config del contenedor
    docker inspect "$CONTAINER" > "$TEMP_BACKUP_DIR/container_config.json" 2>/dev/null || true
    
    # Backup de volúmenes
    for vol in $VOLUMES; do
        VOL_PATH="/var/lib/docker/volumes/$vol/_data"
        if [ -d "$VOL_PATH" ]; then
            echo "[INFO] Copiando volumen: $vol"
            mkdir -p "$TEMP_BACKUP_DIR/volumes/$vol"
            cp -a "$VOL_PATH/." "$TEMP_BACKUP_DIR/volumes/$vol/" 2>/dev/null || true
        fi
    done

    # Crear el archivo comprimido final desde el directorio temporal
    tar -czf "$BACKUP_FILE" -C "$TEMP_BACKUP_DIR" .
} || {
    echo "[ERROR] Falló la creación del backup"
    exit 1
}

# Registrar backup
SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "[OK] Backup creado: $BACKUP_FILE ($SIZE)"
backup_log "OK: $EMPRESA/$SERVICIO - $BACKUP_FILE - $SIZE"
