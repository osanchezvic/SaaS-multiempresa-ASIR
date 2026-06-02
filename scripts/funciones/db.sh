#!/bin/bash

# =========================================
# FUNCIONES BÁSICAS DE BASE DE DATOS (TXT)
# =========================================

# Registrar empresa (si no existe)
db_register_empresa() {
    local empresa="$1"
    
    mkdir -p "$DB_DIR"
    
    if ! grep -q "^$empresa$" "$DB_DIR/empresas.txt" 2>/dev/null; then
        echo "$empresa" >> "$DB_DIR/empresas.txt"
    fi

    # Determinar método de acceso a BD
    if [ -f /.dockerenv ]; then
        # Estamos dentro de un contenedor
        mysql --skip-ssl -h infra_users_db -u users_user -p"$INFRA_DB_PASSWORD" users_db -e "INSERT IGNORE INTO empresas (nombre) VALUES ('$empresa');" 2>/dev/null || true
    else
        # Estamos en el host, usamos docker exec
        if [ -n "$(docker ps -q -f name=infra_users_db)" ]; then
            docker exec infra_users_db mysql --skip-ssl -u users_user -p"$INFRA_DB_PASSWORD" users_db -e "INSERT IGNORE INTO empresas (nombre) VALUES ('$empresa');" 2>/dev/null || true
        fi
    fi
}

# Registrar servicio
db_register_servicio() {
    local empresa="$1"
    local servicio="$2"
    local puerto="$3"
    local url="${4:-}"
    
    mkdir -p "$DB_DIR"
    
    if ! grep -q "^$empresa:$servicio:" "$DB_DIR/servicios.txt" 2>/dev/null; then
        echo "$empresa:$servicio:$puerto:running" >> "$DB_DIR/servicios.txt"
    fi

    local sql_query="
        INSERT INTO servicios_contratados (empresa_id, nombre_servicio, puerto, tipo, url_admin, estado) 
        VALUES ((SELECT id FROM empresas WHERE nombre='$empresa'), '$servicio', $puerto, 'saas', '$url', 'activo')
        ON DUPLICATE KEY UPDATE puerto=$puerto, url_admin='$url', estado='activo';
    "

    if [ -f /.dockerenv ]; then
        mysql --skip-ssl -h infra_users_db -u users_user -p"$INFRA_DB_PASSWORD" users_db -e "$sql_query" 2>/dev/null || true
    else
        if [ -n "$(docker ps -q -f name=infra_users_db)" ]; then
            docker exec infra_users_db mysql --skip-ssl -u users_user -p"$INFRA_DB_PASSWORD" users_db -e "$sql_query" 2>/dev/null || true
        fi
    fi
}

# Obtener puerto de servicio
obtener_puerto() {
    local empresa="$1"
    local servicio="$2"
    
    grep "^$empresa:$servicio:" "$DB_DIR/servicios.txt" 2>/dev/null | cut -d: -f3
}

# Comprobar si servicio existe
servicio_existe() {
    local empresa="$1"
    local servicio="$2"
    
    grep -q "^$empresa:$servicio:" "$DB_DIR/servicios.txt" 2>/dev/null
}

# Listar servicios
listar_servicios() {
    local empresa="${1:-}"
    
    if [ -z "$empresa" ]; then
        cat "$DB_DIR/servicios.txt" 2>/dev/null | column -t -s:
    else
        grep "^$empresa:" "$DB_DIR/servicios.txt" 2>/dev/null | column -t -s:
    fi
}

# Desregistrar servicio (marcar como eliminado)
db_unregister_servicio() {
    local empresa="$1"
    local servicio="$2"

    local sql_query="UPDATE servicios_contratados SET estado='eliminado' WHERE nombre_servicio='$servicio' AND empresa_id=(SELECT id FROM empresas WHERE nombre='$empresa');"

    if [ -f /.dockerenv ]; then
        mysql --skip-ssl -h infra_users_db -u users_user -p"$INFRA_DB_PASSWORD" users_db -e "$sql_query" 2>/dev/null || true
    else
        if [ -n "$(docker ps -q -f name=infra_users_db)" ]; then
            docker exec infra_users_db mysql --skip-ssl -u users_user -p"$INFRA_DB_PASSWORD" users_db -e "$sql_query" 2>/dev/null || true
        fi
    fi
}

# Fijar el estado de un servicio en la BD (activo|inactivo|eliminado)
# Actualiza TODAS las filas que casen empresa+servicio (la tabla puede tener duplicados).
db_set_servicio_estado() {
    local empresa="$1"
    local servicio="$2"
    local estado_db="$3"

    local sql_query="UPDATE servicios_contratados SET estado='$estado_db' WHERE nombre_servicio='$servicio' AND empresa_id=(SELECT id FROM empresas WHERE nombre='$empresa');"

    if [ -f /.dockerenv ]; then
        mysql --skip-ssl -h infra_users_db -u users_user -p"$INFRA_DB_PASSWORD" users_db -e "$sql_query" 2>/dev/null || true
    else
        if [ -n "$(docker ps -q -f name=infra_users_db)" ]; then
            docker exec infra_users_db mysql --skip-ssl -u users_user -p"$INFRA_DB_PASSWORD" users_db -e "$sql_query" 2>/dev/null || true
        fi
    fi
}

# Crear usuario admin en BD infra (para panel)
crear_usuario_admin() {
    local empresa="$1"
    local admin_user="$2"
    local admin_pass="$3"
    
    # Generar hash bcrypt con php (si disponible) o usar openssl para simple hash
    local hash_pass
    if command -v php >/dev/null 2>&1; then
        hash_pass=$(php -r "echo password_hash('$admin_pass', PASSWORD_BCRYPT);")
    else
        hash_pass=$(echo -n "$admin_pass" | openssl dgst -md5 | cut -d' ' -f2)
    fi
    
    local sql_query="
        INSERT INTO usuarios (empresa_id, empresa, usuario, hash_password, rol, es_admin) 
        VALUES ((SELECT id FROM empresas WHERE nombre='$empresa'), '$empresa', '$admin_user', '$hash_pass', 'admin', 0) 
        ON DUPLICATE KEY UPDATE hash_password='$hash_pass';
    "

    if [ -f /.dockerenv ]; then
        mysql -h infra_users_db -u users_user -p$INFRA_DB_PASSWORD users_db -e "$sql_query" 2>/dev/null || true
    else
        if [ -n "$(docker ps -q -f name=infra_users_db)" ]; then
            docker exec infra_users_db mysql -u users_user -p$INFRA_DB_PASSWORD users_db -e "$sql_query" 2>/dev/null || true
        fi
    fi
}

# Exportar funciones
export -f db_register_empresa db_register_servicio db_unregister_servicio db_set_servicio_estado obtener_puerto servicio_existe listar_servicios crear_usuario_admin

