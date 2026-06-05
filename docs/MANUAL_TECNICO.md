# Manual Técnico — TenSaaS

**Plataforma:** TenSaaS · Orquestador multi-tenant de servicios en contenedores
**Audiencia:** operador / administrador de sistemas de la plataforma
**Versión motor:** deploy.sh v2.3 · **Última actualización:** 2026-06-05

> Este manual describe la instalación, la arquitectura, la operación diaria y la resolución de problemas de la plataforma. Está dirigido a quien **gestiona** el servidor (no al cliente final; para eso, ver `MANUAL_USUARIO.md`).

---

## 1. Visión general

TenSaaS aprovisiona, sobre un único servidor, entornos completamente aislados para múltiples empresas (*tenants*). Cada empresa recibe sus servicios bajo un subdominio propio con HTTPS, sin intervención manual. El motor está escrito en **Bash** y se apoya en **Docker / Docker Compose**, **Nginx Proxy Manager** (proxy + SSL), **Authelia** (SSO + 2FA) y **Cloudflare Tunnel** (exposición *zero-exposure*).

Esquema de tráfico:

```
Internet ──HTTPS──> Cloudflare (DNS + Túnel) ──> cloudflared ──> Nginx Proxy Manager
                                                                       │
                                                          (auth_request) ▼
                                                                   Authelia (SSO/2FA)
                                                                       │ OK
                                                                       ▼
                                                        Contenedor del tenant (WordPress, …)
```

El host **no publica ningún puerto** al exterior: todo el tráfico entra por el túnel de Cloudflare.

---

## 2. Requisitos

**Software**
- Linux (probado en Ubuntu 22.04 LTS / Debian 11+).
- Docker Engine ≥ 20 y Docker Compose v2 (plugin CLI).
- Bash ≥ 4, y las utilidades `jq`, `lsof`, `flock`, `curl`, `openssl`, `sed`.

**Hardware**
- Mínimo 8 GB RAM y 4 vCPU; recomendado 16 GB para varias empresas con varios servicios.
- SSD ≥ 256 GB para el sistema y los volúmenes de datos.
- Almacenamiento adicional para backups (disco externo / NAS).
- Conexión con IP fija (fibra simétrica recomendada).

**Servicios de terceros**
- Cuenta de Cloudflare (DNS del dominio + túnel) — plan gratuito suficiente.
- Dominio propio (en este despliegue: `tensaas.es`).
- Let's Encrypt (gestionado por NPM) para los certificados.

---

## 3. Estructura del repositorio

```
TenSaaS/
├── scripts/                 # Motor de orquestación (Bash)
│   ├── deploy.sh            # Despliegue de un servicio para una empresa
│   ├── destroy.sh           # Eliminación segura (con backup previo)
│   ├── list.sh              # Listado de empresas/servicios (table/json/csv)
│   ├── get-credentials.sh   # Consulta de credenciales generadas
│   ├── sync.sh              # Reconciliación registro ↔ Docker (cron 5 min)
│   ├── delete_company.sh    # Baja completa de una empresa
│   ├── catalogo-deps.sh     # Resolución de dependencias del catálogo
│   ├── config.env           # Configuración central del motor
│   ├── databases/           # Registro de estado (servicios.txt, credentials/)
│   ├── logs/                # Logs de cada operación
│   └── funciones/           # Módulos: db, npm, puertos, seguridad, validaciones…
├── catalogo/                # Un subdirectorio por servicio del catálogo
│   └── <servicio>/          # config.yml + docker-compose.tpl + env.tpl
├── infra/                   # Infraestructura global compartida
│   ├── docker-compose.yml   # NPM, Authelia, Portainer, monitorización, API, panel…
│   ├── authelia/config/     # configuration.yml + users.yml
│   ├── api/                 # API FastAPI (puente panel ↔ motor)
│   ├── admin-dashboard/     # Panel PHP de administración
│   └── users-db/            # MariaDB central (users_db) + init.sql
├── data/                    # Volúmenes de datos por empresa (creado en runtime)
└── docs/                    # Documentación (este manual, informes, memoria)
```

---

## 4. Configuración (`scripts/config.env`)

Variables principales (los valores sensibles se omiten):

| Variable | Función |
|----------|---------|
| `PROYECTO_ROOT` | Raíz del repositorio (autodetectada). |
| `DATA_DIR="$PROYECTO_ROOT/data"` | Raíz de los volúmenes de datos de los tenants. |
| `DOCKER_DATA_DIR` | Ruta de datos vista por el daemon Docker (deriva de `HOST_PROJECT_ROOT` si el motor corre en contenedor). |
| `PUERTO_MIN=8100` / `PUERTO_MAX=8999` | Rango de puertos para asignación dinámica. |
| `FORCE_MODE` | `1` = modo no interactivo (omite confirmaciones). |
| `NPM_URL` | Endpoint de la API de NPM (`nginx_proxy_manager:81` en Docker, `localhost:81` en local). |
| `NPM_USER` / `NPM_PASSWORD` | Credenciales de la API de NPM. |
| `NPM_CERT_ID` | ID del certificado *wildcard* reutilizado para los subdominios. |
| `INFRA_DB_PASSWORD` | Contraseña de la BD central `users_db`. |

> Parte de `config.env` (`config.env.example`) sirve de plantilla. Copia y completa los secretos antes de operar.

---

## 5. Puesta en marcha

### 5.1 Infraestructura global
La infra global es lo primero que se levanta y permanece activa siempre:

```bash
cd infra
docker compose up -d
docker compose ps        # comprobar que todo está 'healthy'
```

Esto arranca: Nginx Proxy Manager (+ su BD), cloudflared, Authelia (+ Redis), Portainer, Prometheus/Grafana/Node-exporter/Alertmanager, la API (`infra_api`), el panel (`infra_admin_dashboard`), la BD central (`infra_users_db`) y la landing.

### 5.2 Verificación rápida
```bash
docker ps --filter name=infra
curl -s -o /dev/null -w '%{http_code}\n' https://auth.tensaas.es   # 200
curl -s -o /dev/null -w '%{http_code}\n' https://panel.tensaas.es  # 302 -> login
```

---

## 6. Operación con el motor (scripts)

Todos los scripts se ejecutan desde la raíz del repositorio.

### 6.1 Desplegar un servicio
```bash
./scripts/deploy.sh <empresa> <servicio>
# ejemplo:
./scripts/deploy.sh panaderia wordpress
```
Pipeline (atómico, protegido con `flock`):
`validación → dependencias → puerto libre → credenciales → plantillas → despliegue → proxy+SSL → registro`.

- **Dependencias automáticas:** si el servicio declara `dependencias: [mariadb]` en su `config.yml` y MariaDB no está activa para esa empresa, el motor la despliega antes.
- **Aislamiento:** crea la red `<empresa>_net` si no existe y asigna un puerto libre del rango.
- **Registro:** el estado queda en `scripts/databases/servicios.txt` y en `users_db`.
- El proxy host y el certificado se crean vía la API de NPM (módulo `funciones/npm.sh`).

### 6.2 Listar
```bash
./scripts/list.sh                 # todas las empresas (tabla)
./scripts/list.sh panaderia       # solo una empresa
./scripts/list.sh "" json         # todas, salida JSON
./scripts/list.sh panaderia csv   # una empresa, salida CSV
```
Formatos: `table` (por defecto), `json`, `csv`.

### 6.3 Consultar credenciales
```bash
./scripts/get-credentials.sh <empresa> <servicio>
```
Las credenciales se guardan por servicio en `scripts/databases/credentials/` con permisos `600`.

### 6.4 Destruir un servicio (con backup)
```bash
./scripts/destroy.sh <empresa> <servicio>
```
Tres fases: (1) backup `.tar.gz` de los volúmenes en `/srv/backups/<empresa>/<servicio>/`; (2) confirmación del operador (salvo `FORCE_MODE=1`); (3) parada/eliminación de contenedores, limpieza de volúmenes y del registro/proxy.

### 6.5 Dar de baja una empresa completa
```bash
./scripts/delete_company.sh <empresa>
```

### 6.6 Reconciliación del estado
`sync.sh` cruza `servicios.txt` con la realidad de Docker (corre por cron cada 5 min):
- `running` → línea `:running` (BD: activo)
- parado → `:stopped` (BD: inactivo)
- no existe → borra la línea (BD: eliminado)

```bash
DRY_RUN=true ./scripts/sync.sh    # muestra qué haría, sin escribir
./scripts/sync.sh                 # aplica la reconciliación
```

---

## 7. Catálogo de servicios

Cada servicio vive en `catalogo/<servicio>/` con tres ficheros:

- **`config.yml`** — manifiesto: nombre, descripción, puerto interno, volúmenes y `dependencias`.
- **`docker-compose.tpl`** — plantilla compose con marcadores `{{VARIABLE}}` (`{{EMPRESA}}`, `{{PUERTO}}`, `{{DB_PASSWORD}}`…).
- **`env.tpl`** — variables de entorno del servicio.

El motor sustituye los marcadores con `sed` en tiempo de despliegue.

### Añadir un servicio nuevo
1. Crear `catalogo/<nuevo>/` con los tres ficheros (puedes copiar uno existente como base).
2. Declarar sus `dependencias` en `config.yml` si las tiene.
3. Probar: `./scripts/deploy.sh <empresa_de_prueba> <nuevo>`.

No hay que tocar la lógica central del motor: el catálogo es extensible por convención de carpetas.

**Servicios actuales:** gitea, grafana, jitsi, mariadb, nextcloud, nginx, node-exporter, phpmyadmin, portainer, prestashop, prometheus, redis, uptime-kuma, vaultwarden, vpn (wireguard), wordpress, zabbix.

---

## 8. SSO y control de acceso (Authelia)

### 8.1 Componentes
- **`infra/authelia/config/configuration.yml`** — política de acceso (`access_control`).
- **`infra/authelia/config/users.yml`** — usuarios y grupos (contraseñas en Argon2id).
- NPM hace `auth_request` a Authelia para cada subdominio protegido.

### 8.2 Modelo de aislamiento por tenant
Cada cliente pertenece al grupo de su empresa (`group:<empresa>`). Una **única regla genérica** garantiza que un usuario solo abre los servicios de SU empresa:

```yaml
- domain_regex:
    - "^[a-z0-9]+-(?P<Group>[a-z0-9]+)\\.tensaas\\.es$"
  policy: one_factor
```

El grupo de captura `(?P<Group>…)` exige que el usuario pertenezca al grupo igual a la `<empresa>` capturada del dominio `<servicio>-<empresa>.tensaas.es`. **No hay que añadir reglas al crear empresas nuevas.** Los admins globales (`group:admins`) llegan a todo por la regla maestra `*.tensaas.es two_factor`.

### 8.3 Alta/baja de usuarios
El método recomendado es **el panel** (lo hace todo, incluida la sincronización con Authelia). Internamente el panel llama a la API:
- `POST /auth/sync_user` (genera el hash Argon2, escribe `users.yml`, reinicia Authelia).
- `POST /auth/remove_user/{username}`.

El dashboard asigna automáticamente `group:<empresa>` a los usuarios no-admin (ver `infra/admin-dashboard/usuarios.php`).

> **Importante:** borrar usuarios por SQL directo en `users_db` **no** los elimina de Authelia. Usa el panel o llama a `remove_user` para mantener ambos en sincronía.

### 8.4 Validar la configuración sin reiniciar
```bash
docker run --rm -v "$PWD/infra/authelia/config":/config:ro \
  authelia/authelia:4.39.20 authelia validate-config --config /config/configuration.yml
```

---

## 9. Panel de administración y API

- **Panel (PHP):** `https://panel.tensaas.es` — consulta `users_db`, muestra empresas/servicios y permite desplegar/eliminar y gestionar usuarios. Protegido por Authelia + login propio (sesión `es_admin`).
- **API (FastAPI, `infra_api`):** capa REST que ejecuta los scripts del motor y sincroniza usuarios. Endpoints relevantes: `/deploy`, `/destroy`, `/auth/sync_user`, `/auth/remove_user`, `/contact`, `/api/v1/system/status`.
- **BD central (`users_db`, MariaDB):** tablas `empresas`, `usuarios`, `servicios_contratados`, `access_logs`.

---

## 10. Backups y recuperación

- **Backup previo a destrucción:** `destroy.sh` comprime los volúmenes a `.tar.gz`.
- **Backup independiente:** `infra/backups/backup.sh` por empresa/servicio; programable por cron (p. ej. diario a las 3:00). Destino `/srv/backups/` (var. `BACKUP_BASE_DIR`), retención 30 días.
- **DR:** el sistema es reproducible desde Git + volúmenes restaurados. Objetivo a futuro: copia externa (S3/NAS) para cumplir la regla 3-2-1.

---

## 11. Monitorización

- **Prometheus** recoge métricas del host (Node-exporter) y de los contenedores.
- **Grafana** las visualiza (CPU, RAM, disco, estado de servicios).
- **Uptime Kuma** vigila las URL públicas.
- **Alertmanager** envía alertas críticas a **Telegram**.

---

## 12. Resolución de problemas

| Síntoma | Causa probable | Diagnóstico / solución |
|---------|----------------|------------------------|
| **403** al abrir un servicio | El usuario no está en el grupo de su empresa, o la empresa no casa el esquema de dominio | `docker logs authelia --since 10m \| grep -i forbidden`. Verificar que el usuario tiene `group:<empresa>` en `users.yml` y que el dominio es `<servicio>-<empresa>.tensaas.es`. |
| **401 → login** en bucle | Sesión SSO caducada o cookie de Authelia | Reautenticar; comprobar Redis (`docker ps \| grep redis`). |
| **502** tras desplegar | NPM apunta a un puerto/host equivocado | Revisar el proxy host en NPM; el motor deriva el puerto interno del contenedor. Reintentar el registro del host. |
| **Servicio en registro pero no en Docker** (o viceversa) | *Drift* del estado | `DRY_RUN=true ./scripts/sync.sh` y luego `./scripts/sync.sh`. |
| **Empresa nueva no accede a sus servicios** | Usuario sin `group:<empresa>` | Crear el usuario desde el panel (asigna el grupo solo) o añadir el grupo en `users.yml` y reiniciar Authelia. |
| **Authelia no arranca** | Error en `configuration.yml`/`users.yml` | Validar con `authelia validate-config` (ver §8.4); `docker logs authelia`. |

Logs útiles:
```bash
tail -f scripts/logs/<empresa>_<servicio>_<fecha>.log   # despliegue
docker logs -f authelia | grep -i verify                # SSO
tail -f scripts/logs/sync.log                           # reconciliación
```

---

## 13. Notas de seguridad (estado conocido)

- Los ficheros `infra/authelia/config/` están en `0777` → conviene endurecer a `750`/`640`.
- La API genera hashes ejecutando `docker run authelia/authelia` por petición (coste/superficie); roadmap: usar la CLI/librería local.
- Imágenes con tag `:latest` en varias piezas → roadmap: fijar versiones / digests.
- `init.sql` siembra `admin/password` (no presente en la BD viva, pero conviene quitarlo del script).
- Trivy (`seguridad.sh`) no bloquea aún el pipeline.

Para el detalle completo y el plan de remediación priorizado, ver `docs/INFORME_ESTADO_2026-06.md`.
