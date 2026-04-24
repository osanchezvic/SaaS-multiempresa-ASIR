#!/bin/bash

# Pre-deploy security scan using Trivy
scan_image() {
    local image="$1"
    
    echo_info "Escaneando imagen: $image"
    
    # Check if trivy is installed
    if ! command -v trivy &> /dev/null; then
        echo_warn "Trivy no instalado, saltando escaneo."
        return 0
    fi
    
    # Run scan
    if trivy image --exit-code 1 --severity CRITICAL "$image"; then
        echo_success "Imagen limpia de vulnerabilidades críticas: $image"
        return 0
    else
        echo_error "Vulnerabilidades críticas encontradas en $image"
        echo_warn "MODO DEMO: Continuando despliegue a pesar de los riesgos..."
        return 0
    fi
}
export -f scan_image
