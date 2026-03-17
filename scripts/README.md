# Scripts - BASH
Esta carpeta contiene el **motor de despliegue** de la plataforma. Aquí se gestionan las empresas, los servicios, los puertos y la generación de archivos a partir del catálogo.
En cada git pull hay que volver a dar permisos:
chmod +x scripts/*.sh
chmod -R +x scripts/funciones/

## Contenido

- `deploy.sh` — Script principal para desplegar servicios.
- `utils.sh` — Funciones genéricas (logs, generación de claves, validaciones).
- `variables.sh` — Configuración global del sistema.
- `puertos.db` — Registro de puertos asignados.
- `empresas.db` — Registro de empresas creadas.
- `funciones/` — Módulos internos del sistema:
  - `redes.sh` — Gestión de redes Docker por empresa.
  - `servicios.sh` — Instalación y validación de servicios.
  - `plantillas.sh` — Procesado de plantillas del catálogo.
  - `puertos.sh` — Asignación y control de puertos.
  - `empresas.sh` — Creación y gestión de empresas.
  - `seguridad.sh` — Generación de contraseñas y tokens.
- `logs/` — Registros de despliegues.

## Uso

Desplegar un servicio para una empresa:

```bash
./deploy.sh empresa servicio
```

Ejemplos:

```bash
./deploy.sh panaderia wordpress
./deploy.sh clinica grafana
```

El sistema crea la empresa si no existe, asigna puertos, genera variables, copia plantillas y levanta el servicio automáticamente.
