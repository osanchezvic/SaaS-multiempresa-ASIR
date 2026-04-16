# Infraestructura Global

Este directorio contiene la configuración y los scripts para desplegar y gestionar los servicios de infraestructura comunes que dan soporte a la plataforma IaaS Multiempresa.

## Servicios Incluidos

- **Portainer:** Interfaz de gestión de Docker.
- **Node Exporter:** Recopila métricas del sistema para Prometheus.
- **Prometheus:** Sistema de monitorización y alertas.
- **Grafana:** Plataforma de visualización de métricas y dashboards.
- **Nginx Proxy Manager (NPM):** Proxy inverso para gestionar el acceso a servicios.
- **NPM Database (MariaDB):** Base de datos para NPM.
- **Watchtower:** Actualización automática de contenedores Docker.
- **Fail2Ban:** Protección contra ataques de fuerza bruta.
- **Loki:** Sistema de agregación de logs centralizado.
- **Promtail:** Agente para enviar logs de contenedores a Loki.

## Estructura

```text
infra/
├── .env                  # Variables de entorno sensibles (contraseñas, configuraciones)
├── docker-compose.yml    # Definición de todos los servicios de infraestructura
├── deploy-infra.sh       # Script para desplegar/parar/reiniciar la infraestructura
├── infra/                # Subdirectorios para configuraciones específicas:
│   ├── backups/          # Configuración de backups (script, config, readme)
│   ├── monitorizacion/   # Configuración de Prometheus/Grafana
│   │   ├── grafana/
│   │   ├── node-exporter/
│   │   └── prometheus/
│   ├── proxy/            # Configuración de Nginx Proxy Manager
│   ├── seguridad/
│   │   └── fail2ban/     # Configuración de Fail2ban
│   ├── promtail-config.yaml # Configuración del agente de logs Promtail
│   └── grafana/
│       └── provisioning/
│           └── datasources/
│               └── datasources.yml # Configuración de fuentes de datos para Grafana (incluye Loki)
└── README.md             # Este archivo de documentación
```

## Despliegue y Gestión

El despliegue y la gestión de la infraestructura global se realizan a través del script `deploy-infra.sh` y el archivo central `docker-compose.yml`.

### 1. Preparación:

Es crucial crear y configurar el archivo `.env` antes del primer despliegue para definir las variables de entorno sensibles.

```bash
cp infra/.env.example infra/.env
# Edita infra/.env con tus contraseñas y configuraciones deseadas.
```

### 2. Despliegue:

```bash
cd infra
./deploy-infra.sh start
```

### 3. Parada:

```bash
cd infra
./deploy-infra.sh stop
```

### 4. Reinicio:

```bash
cd infra
./deploy-infra.sh restart
```

## Configuración de Servicios

### Grafana

- **Acceso:** `http://localhost:3000`
- **Credenciales por defecto:** Usuario `admin`, Contraseña `admin123` (configurable via `GRAFANA_ADMIN_USER` y `GRAFANA_ADMIN_PASSWORD` en `.env`).
- **Fuente de Datos Loki:** Configurada automáticamente a través de `grafana/provisioning/datasources/datasources.yml`.

### Nginx Proxy Manager

- **Acceso:** `http://localhost:81`
- **Credenciales por defecto:** `admin@example.com` / `changeme`.
- **Base de Datos:** Utiliza el servicio `npm_db` definido en `docker-compose.yml`, con credenciales configurables vía `.env`.

### Fail2Ban

- **Configuración:** Se utiliza el archivo `seguridad/fail2ban/jail.local` para definir las reglas de banneo.
- **Logs:** Accede a los logs de Fail2Ban a través de Loki o directamente en `/var/log/` si es necesario.
