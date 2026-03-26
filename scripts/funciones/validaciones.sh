#!/bin/bash

# =========================================
# VALIDACIONES BÁSICAS Y DEPENDENCIAS
# =========================================

# Validar servicio en catálogo
validar_servicio() {
    local servicio="$1"
    
    if [ ! -d "$CATALOGO_DIR/$servicio" ]; then
        echo_error "Servicio no existe: $servicio"
        echo_info "Disponibles: $(ls $CATALOGO_DIR)"
        return 1
    fi
    
    if [ ! -f "$CATALOGO_DIR/$servicio/config.yml" ]; then
        echo_error "Falta config.yml en $servicio"
        return 1
    fi
    
    return 0
}

# Obtener dependencias de un servicio desde config.yml
obtener_dependencias() {
    local servicio="$1"
    local config_file="$CATALOGO_DIR/$servicio/config.yml"
    
    if [ ! -f "$config_file" ]; then
        return
    fi
    
    # Buscar línea "dependencias:" y extraer lista
    grep -A 10 "^dependencias:" "$config_file" 2>/dev/null | grep "^  - " | sed 's/^  - //' || true
}

# Validar y resolver dependencias automáticamente
validar_dependencias_auto() {
    local empresa="$1"
    local servicio="$2"
    
    echo_info "Verificando dependencias de $servicio..."
    
    local deps=$(obtener_dependencias "$servicio")
    
    if [ -z "$deps" ]; then
        echo_debug "Sin dependencias"
        return 0
    fi
    
    while read -r dep; do
        if [ -z "$dep" ]; then
            continue
        fi
        
        echo_debug "Validando dependencia: $dep"
        
        # Verificar si la dependencia ya existe para esta empresa
        if servicio_existe "$empresa" "$dep"; then
            echo_info "Dependencia OK: $empresa/$dep ya existe"
        else
            echo_warn "Dependencia FALTA: $empresa/$dep"
            
            # Mostrar info de dependencia
            if validar_servicio "$dep"; then
                echo_info "Instalando dependencia: $dep..."
                
                # Desplegar dependencia automáticamente
                cd "$SCRIPT_PATH" || return 1
                
                if ./deploy.sh "$empresa" "$dep" >/dev/null 2>&1; then
                    echo_info "Dependencia instalada: $empresa/$dep"
                else
                    echo_error "Error instalando dependencia: $empresa/$dep"
                    echo_info "Intenta manualmente: ./deploy.sh $empresa $dep"
                    return 1
                fi
            else
                echo_error "Error: no pude validar la dependencia $dep"
                return 1
            fi
        fi
    done <<< "$deps"
    
    return 0
}

# Pre-validaciones antes del deploy
validar_pre_deploy() {
    local empresa="$1"
    local servicio="$2"
    
    # Validar nombre empresa
    if ! validar_nombre "$empresa"; then
        return 1
    fi
    
    # Validar nombre servicio
    if ! validar_nombre "$servicio"; then
        return 1
    fi
    
    # Validar servicio existe en catálogo
    if ! validar_servicio "$servicio"; then
        return 1
    fi
    
    # Validar y resolver dependencias automáticamente
    if ! validar_dependencias_auto "$empresa" "$servicio"; then
        echo_error "No se pudieron resolver dependencias"
        return 1
    fi
    
    return 0
}

# Post-validaciones después del deploy
validar_post_deploy() {
    local empresa="$1"
    local servicio="$2"
    local container="${empresa}_${servicio}_1"
    
    echo_info "Validaciones post-deploy en curso..."
    
    # Verificar que contenedor existe
    if ! docker ps -a | grep -q "$container"; then
        echo_error "Contenedor no encontrado: $container"
        return 1
    fi
    
    # Esperar a que esté running
    local max_intentos=30
    local intento=0
    
    while [ $intento -lt $max_intentos ]; do
        if docker ps | grep -q "$container"; then
            echo_info "Contenedor corriendo: $container"
            return 0
        fi
        
        intento=$((intento + 1))
        echo_debug "Esperando contenedor... ($intento/$max_intentos)"
        sleep 2
    done
    
    echo_error "Timeout esperando contenedor"
    return 1
}


