#!/bin/bash

# 1. Parámetros
EMPRESA=$1
SERVICIO=$2

if [ $# -lt 3 ]; then
    echo "Uso: ./scripts/deploy.sh <empresa> <servicio>"
    exit 1
fi

# Si alguno de los parámetros está vacio exit
if [ -z "$EMPRESA" ] || [ -z "$SERVICIO" ]; then
    echo "Uso: ./scripts/deploy.sh <empresa> <servicio>"
    exit 1
fi

# 2. Definir rutas basandose en la ubicación del script
# Esto detecta la carpeta 'scripts' y sube un nivel a la raíz del proyecto
SCRIPT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROYECTO_ROOT=$(dirname "$SCRIPT_PATH")

CATALOGO_DIR="$PROYECTO_ROOT/catalogo/$SERVICIO"
BASE_DIR="/srv/$EMPRESA"
SERVICIO_DIR="$BASE_DIR/$SERVICIO"

# Si el servicio no existe en el catálogo exit
if [ ! -d "$CATALOGO_DIR" ]; then
    echo "Error: El servicio '$SERVICIO' no existe en el catálogo."
    echo "Servicios disponibles: $(ls "$PROYECTO_ROOT/catalogo" | xargs)"
    exit 2
fi

mkdir -p "$SERVICIO_DIR"

# 3. Generar valores dinámicos
PUERTO=$(shuf -i 8000-8999 -n 1)
DB_NAME="${EMPRESA}_db"
DB_USER="${EMPRESA}_user"
DB_PASSWORD=$(openssl rand -hex 8)
ADMIN_USER="admin"
ADMIN_PASSWORD=$(openssl rand -hex 8)

# 4. Se utiliza el comando 'sed' para buscar y cambiar las marcas de los .tpl
# Hay que utilizar '|' para evitar conflictos con barras de rutas !!!
sed -e "s|{{EMPRESA}}|$EMPRESA|g" \
    -e "s|{{PUERTO}}|$PUERTO|g" \
    -e "s|{{RUTA_DATOS}}|$BASE_DIR|g" \
    -e "s|{{DB_NAME}}|$DB_NAME|g" \
    -e "s|{{DB_USER}}|$DB_USER|g" \
    -e "s|{{DB_PASSWORD}}|$DB_PASSWORD|g" \
    "$CATALOGO_DIR/docker-compose.tpl" > "$SERVICIO_DIR/docker-compose.yml"

sed -e "s|{{DB_NAME}}|$DB_NAME|g" \
    -e "s|{{DB_USER}}|$DB_USER|g" \
    -e "s|{{DB_PASSWORD}}|$DB_PASSWORD|g" \
    -e "s|{{ADMIN_USER}}|$ADMIN_USER|g" \
    -e "s|{{ADMIN_PASSWORD}}|$ADMIN_PASSWORD|g" \
    "$CATALOGO_DIR/env.tpl" > "$SERVICIO_DIR/.env"

# 5. Red de Docker | Si no existe la crea
docker network inspect "${EMPRESA}_net" >/dev/null 2>&1 || \
    docker network create "${EMPRESA}_net"

# 6. Despliegue
cd "$SERVICIO_DIR" || exit 3
docker compose up -d

echo "================================================"
echo "DESPLIEGE COMPLETADO"
IP=$(hostname -I | awk '{print $1}')
echo "URL: http://$IP:$PUERTO"
echo "Empresa: $EMPRESA | Servicio: $SERVICIO"
echo "Credenciales DB: $DB_USER / $DB_PASSWORD"
echo "Credenciales Admin: $ADMIN_USER / $ADMIN_PASSWORD"
echo "================================================"
