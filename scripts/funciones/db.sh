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

    # Determinar host de BD
    local db_host="localhost"
    local db_port="3307"
    if [ -f /.dockerenv ]; then
        db_host="infra_users_db"
        db_port="3306"
    fi

    # Registrar en MariaDB infra si está disponible
    mysql -h "$db_host" -P "$db_port" -u users_user -pusers_pass users_db -e "
        INSERT IGNORE INTO empresas (nombre) VALUES ('$empresa');
    " 2>/dev/null || true
}

# Registrar servicio
# Formato: empresa:servicio:puerto:status
db_register_servicio() {
    local empresa="$1"
    local servicio="$2"
    local puerto="$3"
    
    mkdir -p "$DB_DIR"
    
    if ! grep -q "^$empresa:$servicio:" "$DB_DIR/servicios.txt" 2>/dev/null; then
        echo "$empresa:$servicio:$puerto:running" >> "$DB_DIR/servicios.txt"
    fi

    # Determinar host de BD
    local db_host="localhost"
    local db_port="3307"
    if [ -f /.dockerenv ]; then
        db_host="infra_users_db"
        db_port="3306"
    fi

    # Registrar en MariaDB infra si está disponible
    # Primero obtener ID de empresa
    local emp_id=$(mysql -h "$db_host" -P "$db_port" -u users_user -pusers_pass users_db -N -s -e "SELECT id FROM empresas WHERE nombre='$empresa';" 2>/dev/null || echo "")
    
    if [ -n "$emp_id" ]; then
        mysql -h "$db_host" -P "$db_port" -u users_user -pusers_pass users_db -e "
            INSERT INTO servicios_contratados (empresa_id, nombre_servicio, puerto, tipo, estado) 
            VALUES ($emp_id, '$servicio', $puerto, 'saas', 'activo')
            ON DUPLICATE KEY UPDATE puerto=$puerto, estado='activo';
        " 2>/dev/null || true
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
    
    # Determinar host de BD
    local db_host="localhost"
    local db_port="3307"
    if [ -f /.dockerenv ]; then
        db_host="infra_users_db"
        db_port="3306"
    fi

    # Insertar en BD infra_users_db
    # Mapeamos 'admin' a es_admin=1 si es necesario, o lo dejamos para la lógica del dashboard
    mysql -h "$db_host" -P "$db_port" -u users_user -pusers_pass users_db -e "
        INSERT INTO usuarios (empresa_id, empresa, usuario, hash_password, rol, es_admin) 
        VALUES ((SELECT id FROM empresas WHERE nombre='$empresa'), '$empresa', '$admin_user', '$hash_pass', 'admin', 0) 
        ON DUPLICATE KEY UPDATE hash_password='$hash_pass';
    " 2>/dev/null || log_warn "No se pudo insertar usuario admin en BD infra (BD no disponible?)"
}

# Exportar funciones
export -f db_register_empresa db_register_servicio obtener_puerto servicio_existe listar_servicios crear_usuario_admin

