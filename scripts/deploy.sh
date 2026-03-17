#!/bin/bash

# ============================
# 1. Recoger parámetros
# ============================
EMPRESA=$1
SERVICIO=$2

if [ -z "$EMPRESA" ] || [ -z "$SERVICIO" ]; then
    echo "Uso: ./deploy.sh <empresa> <servicio>"
    exit 1
fi

# ============================
# 2. Definir rutas
# ============================
BASE_DIR="/srv/$EMPRESA"
SERVICIO_DIR="$BASE_DIR/$SERVICIO"
CATALOGO_DIR="./catalogo/$SERVICIO"

mkdir -p "$SERVICIO_DIR"

# ============================
# 3. Generar valores dinámicos
# ============================
PUERTO=$(shuf -i 8000-8999 -n 1)
DB_NAME="${EMPRESA}_db"
DB_USER="${EMPRESA}_user"
DB_PASSWORD=$(openssl rand -hex 8)
ADMIN_USER="admin"
ADMIN_PASSWORD=$(openssl rand -hex 8)

# ============================
# 4. Sustituir variables en docker-compose.tpl
# ============================
sed \
    -e "s/{{EMPRESA}}/$EMPRESA/g" \
    -e "s/{{PUERTO}}/$PUERTO/g" \
    -e "s/{{RUTA_DATOS}}/$BASE_DIR/g" \
    -e "s/{{DB_NAME}}/$DB_NAME/g" \
    -e "s/{{DB_USER}}/$DB_USER/g" \
    -e "s/{{DB_PASSWORD}}/$DB_PASSWORD/g" \
    "$CATALOGO_DIR/docker-compose.tpl" \
    > "$SERVICIO_DIR/docker-compose.yml"

# ============================
# 5. Sustituir variables en env.tpl
# ============================
sed \
    -e "s/{{DB_NAME}}/$DB_NAME/g" \
    -e "s/{{DB_USER}}/$DB_USER/g" \
    -e "s/{{DB_PASSWORD}}/$DB_PASSWORD/g" \
    -e "s/{{ADMIN_USER}}/$ADMIN_USER/g" \
    -e "s/{{ADMIN_PASSWORD}}/$ADMIN_PASSWORD/g" \
    "$CATALOGO_DIR/env.tpl" \
    > "$SERVICIO_DIR/.env"

# ============================
# 6. Crear red si no existe
# ============================
docker network inspect "${EMPRESA}_net" >/dev/null 2>&1 || \
    docker network create "${EMPRESA}_net"

# ============================
# 7. Levantar el servicio
# ============================
cd "$SERVICIO_DIR"
docker compose up -d

echo "Servicio $SERVICIO desplegado para la empresa $EMPRESA"
echo "Puerto asignado: $PUERTO"
echo "Usuario admin: $ADMIN_USER"
echo "Contraseña admin: $ADMIN_PASSWORD"
