#!/bin/bash

# ============================================
# UTILIDADES GENÉRICAS
# ============================================

# Validar nombre válido (empresa, servicio)
validar_nombre() {
    local nombre="$1"
    
    # No vacío
    if [ -z "$nombre" ]; then
        echo_error "Nombre no puede estar vacío"
        return 1
    fi
    
    # Solo alfanuméricos y guiones
    if ! [[ "$nombre" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo_error "Nombre inválido: '$nombre'. Solo alfanuméricos, guiones y guiones bajos"
        return 1
    fi
    
    # Longitud
    if [ ${#nombre} -lt 2 ] || [ ${#nombre} -gt 30 ]; then
        echo_error "Nombre debe tener entre 2 y 30 caracteres"
        return 1
    fi
    
    return 0
}

# Confirmar acción (interactivo)
confirmar() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$FORCE_MODE" -eq 1 ] 2>/dev/null; then
        return 0
    fi
    
    local response
    if [ "$default" = "y" ]; then
        read -p "$prompt (Y/n): " response
        [ -z "$response" ] && response="y"
    else
        read -p "$prompt (y/N): " response
        [ -z "$response" ] && response="n"
    fi
    
    case "$response" in
        [yY]) return 0 ;;
        [nN]) return 1 ;;
        *) confirmar "$prompt" "$default" ;;
    esac
}

# Generar contraseña aleatoria
generar_password() {
    local length="${1:-16}"
    openssl rand -hex "$((length / 2))" | cut -c1-$length
}

# Generar token aleatorio
generar_token() {
    local length="${1:-32}"
    openssl rand -hex "$((length / 2))" | cut -c1-$length
}

# Guardar credenciales (txt simple)
guardar_credenciales() {
    local empresa="$1"
    local servicio="$2"
    local credenciales_json="$3"
    
    mkdir -p "$CREDENTIALS_DIR"
    local cred_file="$CREDENTIALS_DIR/${empresa}.${servicio}"
    
    echo "$credenciales_json" > "$cred_file"
    chmod 600 "$cred_file"
    
    echo "$cred_file"
}

# Leer credenciales como JSON
leer_credenciales_json() {
    local empresa="$1"
    local servicio="$2"
    
    local cred_file="$CREDENTIALS_DIR/${empresa}.${servicio}"
    
    if [ ! -f "$cred_file" ]; then
        echo_error "Credenciales no encontradas: $cred_file"
        return 1
    fi
    
    cat "$cred_file"
}

# Leer credenciales como JSON
leer_credenciales_json() {
    local empresa="$1"
    local servicio="$2"
    
    local cred_file="$CREDENTIALS_DIR/${empresa}.${servicio}"
    
    if [ ! -f "$cred_file" ]; then
        echo_error "Credenciales no encontradas: $cred_file"
        return 1
    fi
    
    cat "$cred_file"
}

# Leer credenciales (txt simple con grep)
leer_credenciales() {
    local empresa="$1"
    local servicio="$2"
    local clave="$3"
    
    local cred_file="$CREDENTIALS_DIR/${empresa}.${servicio}"
    
    if [ ! -f "$cred_file" ]; then
        echo_error "Credenciales no encontradas: $cred_file"
        return 1
    fi
    
    grep "^${clave}=" "$cred_file" | cut -d'=' -f2
}

# Backup de servicio
backup_servicio() {
    local empresa="$1"
    local servicio="$2"
    local servicio_dir="$DATA_DIR/$empresa/$servicio"
    local backup_dir="$PROYECTO_ROOT/backups/$empresa/$servicio"
    local timestamp=$(date +%Y%m%d%H%M%S)
    
    if [ ! -d "$servicio_dir" ]; then
        return 0
    fi

    mkdir -p "$backup_dir"
    tar -czf "$backup_dir/${servicio}_${timestamp}.tar.gz" -C "$servicio_dir" .
    echo "$backup_dir/${servicio}_${timestamp}.tar.gz"
}

# Exportar funciones
export -f validar_nombre confirmar generar_password generar_token guardar_credenciales leer_credenciales leer_credenciales_json backup_servicio

