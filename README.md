# Plataforma SaaS Multiempresa
 
Plataforma de gestión SaaS automatizada diseñada para orquestar servicios basados en Docker en entornos multiempresa. El sistema centraliza el despliegue, la configuración y el mantenimiento de servicios aislados para múltiples inquilinos (tenants).

## Arquitectura

El sistema emplea un enfoque basado en catálogo para desplegar servicios aislados. Automatiza los siguientes procesos críticos:
- Resolución de dependencias entre servicios.
- Asignación dinámica de puertos y prevención de colisiones.
- Gestión de secretos y credenciales.
- Copias de seguridad automáticas antes de operaciones destructivas.
- Aislamiento de red (redes Docker dedicadas por empresa).

## Estructura del Proyecto

```text
/
├── catalogo/        # Definiciones de servicios (templates docker-compose)
├── infra/           # Infraestructura global (proxy, monitorización, gestión)
├── scripts/         # Lógica central de orquestación
│   ├── funciones/   # Módulos bash reutilizables
│   └── databases/   # Gestión de estado (JSON/Texto plano)
└── docs/            # Documentación técnica
```

## Características Principales

- **Resolución Automática de Dependencias:** Gestión de despliegue en cascada. Si un servicio (ej. `wordpress`) requiere otro (ej. `mariadb`), el orquestador valida e instala la dependencia automáticamente si no está presente.
- **Aislamiento Multiempresa:** Cada inquilino opera en una red Docker privada, garantizando la separación de servicios y datos.
- **Seguridad:** Gestión de secretos con permisos de sistema restringidos (chmod 600) para evitar accesos no autorizados.
- **Integridad de Datos:** Mecanismo de respaldo automático (archivos .tar.gz) integrado en el ciclo de vida de destrucción de servicios.

## Uso

### Despliegue

```bash
./scripts/deploy.sh <empresa> <servicio>
```
*El sistema resolverá automáticamente cualquier dependencia definida en el manifiesto del servicio.*

### Gestión de Servicios

| Comando | Descripción |
| :--- | :--- |
| `./scripts/deploy.sh <empresa> <servicio>` | Despliega un servicio y sus dependencias. |
| `./scripts/list.sh [empresa] [formato]` | Lista servicios desplegados (tabla/json/csv). |
| `./scripts/get-credentials.sh <empresa> <servicio>` | Recupera credenciales del servicio. |
| `./scripts/destroy.sh <empresa> <servicio>` | Elimina el servicio y genera un backup automático. |

## Lógica de Dependencias

La relación de dependencias se define en los archivos `config.yml` dentro de `catalogo/`. El orquestador, a través del script `scripts/catalogo-deps.sh` y la validación previa al despliegue, garantiza que los prerrequisitos existan antes de la instanciación de cualquier servicio.

## Configuración

- **Directorio de Datos:** Definido por la variable `DATA_DIR` en `scripts/config.env` (por defecto: `/srv`).
- **Gestión de Puertos:** Rango configurable mediante `PUERTO_MIN` y `PUERTO_MAX` en `scripts/config.env`.

## Seguridad

- **Gestión de Secretos:** El sistema utiliza variables de entorno para la configuración sensible. Asegúrese de configurar las siguientes variables antes de desplegar:
  - `GRAFANA_ADMIN_PASSWORD`
  - `NPM_DB_PASSWORD`
  - `NPM_DB_ROOT_PASSWORD`
  
  Consulte `scripts/config.env` para más detalles sobre las configuraciones disponibles.

## Requisitos

- Docker (versión 20+)
- Docker Compose (versión 2+)
- Bash (4.0+)
- Linux (Ubuntu/Debian recomendado)
