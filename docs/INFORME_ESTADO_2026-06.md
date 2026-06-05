# INFORME DE ESTADO — TenSaaS
**Fecha:** 2026-06-04 · **Actualizado:** 2026-06-05 · **Autor del análisis:** revisión DevOps/SysAdmin · **Versión motor:** deploy.sh v2.3

> **Nota de actualización (2026-06-05):** resuelto el hallazgo **O2** (las reglas de Authelia ya no se *hardcodean* por empresa; ahora hay una única regla genérica con aislamiento por tenant que escala a empresas futuras). Ver el detalle en la nueva sección **6. Cambios aplicados**.

## 1. Resumen ejecutivo

TenSaaS es un orquestador multi-tenant **funcional y en producción** (27 contenedores activos, 7 empresas, ~11 servicios tenant corriendo) con una arquitectura perimetral sólida (zero-exposure vía Cloudflare Tunnel, SSO Authelia con 2FA, aislamiento de red por tenant). El diseño es ambicioso y mayoritariamente coherente para un PFC de ASIR; varias decisiones (proyecto compose por empresa+servicio, reconciliación con `sync.sh`, persistencia híbrida txt+MariaDB) están bien razonadas y documentadas en el propio código.

El proyecto, sin embargo, arrastra **riesgos de seguridad y de operación** que conviene cerrar antes de presentarlo/escalarlo. Los más relevantes:

- **Deriva documentación ↔ realidad**: `dashy` y `watchtower` siguen **corriendo** pese a que `SEGURIDAD_REMEDIACION.md` los declara eliminados; `watchtower_global` está además `unhealthy`. El README documenta 4 servicios de catálogo cuando hay **17**.
- **Reproducibilidad/cadena de suministro**: uso masivo de tags `:latest` **+ Watchtower activo** = actualizaciones automáticas no controladas, sin pinning ni reproducibilidad.
- **Seguridad aplicativa**: inyección SQL por interpolación de cadenas en `db.sh`; CORS `*` con credenciales y endpoint `/contact` sin autenticar (relay de correo abusable) en la API; `seguridad.sh` (Trivy) que **nunca bloquea**; usuario `admin/password` sembrado en `init.sql`.
- **Resiliencia**: 0/17 plantillas de catálogo definen **healthchecks** o **límites de recursos** (CPU/RAM).
- **Permisos**: `infra/authelia/config` en `0777` (incluida `configuration.yml` con secretos resueltos y `db.sqlite3`).

Veredicto: **base muy buena, lista para demo, no lista para “producción real” sin cerrar los P0**. Lo positivo es que casi todos los hallazgos son acotados y de remediación rápida.

## 2. Estado real desplegado (runtime)

- **Infra global (sana):** cloudflared, nginx_proxy_manager (healthy), npm_db, authelia (healthy), redis, prometheus/grafana/node-exporter (healthy), alertmanager, portainer, infra_api, infra_admin_dashboard, infra_users_db, landing_page.
- **Tenants corriendo (11):** panaderia (gitea, phpmyadmin, uptime-kuma, wordpress, prestashop, mariadb), fruteria (wordpress, mariadb, gitea), empresa01 (wordpress, mariadb).
- **Contenedores “fantasma” (no deberían estar):** `dashy_portal`, `watchtower_global` (**unhealthy**).
- **Redes:** correcto aislamiento `*_net` por tenant + `infra_net`/`infra_proxy_net`. El host es **compartido** con otros proyectos personales (`immich`, `portfolio`, `duckdns`) → a tener en cuenta para Watchtower y para recursos.
- **Registro vs realidad:** `sync.sh` (cron 5 min) reconcilia bien; último run coherente (11 running / 1 stopped: `martincodax/gitea`). Hay **datos huérfanos en disco** de tenants ya no activos: `data/btravel`, `data/testco`, `data/test_env`, `data/martincodax`.

## 3. Fortalezas (lo que está bien hecho)

1. **Perímetro zero-exposure real:** el host no publica puertos; NPM solo escucha en `127.0.0.1:81`. Buen modelo de amenaza.
2. **Aislamiento multi-tenant** en red (bridge por empresa), datos (`/data/<empresa>/<servicio>`) y secretos (JSON `chmod 600`).
3. **Motor robusto en detalles no triviales:** `flock` contra concurrencia, proyecto compose único `empresa_servicio` (evita pisado entre tenants), derivación del puerto interno para NPM, normalización guion→guion_bajo.
4. **`sync.sh` de calidad:** snapshot único de Docker, modo `DRY_RUN`, backup previo, aviso de *drift inverso*, y mitigación explícita del bug SIGPIPE+pipefail.
5. **Dashboard PHP correcto en seguridad básica:** prepared statements, `password_verify`, tokens CSRF, separación de sesión admin vs tenant (`es_admin`), `htmlspecialchars` en salida.
6. **SSO Authelia** con Argon2id, regulación de reintentos (ban) y `default_policy: deny`.
7. **Observabilidad** Prometheus + Grafana + Alertmanager→Telegram desplegada y *healthy*.

## 4. Hallazgos (por categoría y severidad)

> Severidad: 🔴 Crítico · 🟠 Alto · 🟡 Medio · ⚪ Bajo

### 4.1 Seguridad

| # | Sev | Hallazgo | Evidencia |
|---|-----|----------|-----------|
| S1 | 🔴 | **Inyección SQL** por interpolación directa de variables en consultas | `scripts/funciones/db.sh` (`db_register_empresa/servicio`, `crear_usuario_admin`, `db_set_servicio_estado`): `... VALUES ('$empresa')`. Mitigado parcialmente porque `deploy.sh` valida nombres, pero `db.sh` es reutilizable y no valida por sí mismo. |
| S2 | 🔴 | **Usuario admin por defecto `admin`/`password`** (`es_admin=1`) sembrado en el esquema | `infra/users-db/init.sql:56-57`. Si no se rotó en la BD viva, es acceso total al panel. **Verificar y eliminar/rotar.** |
| S3 | 🟠 | **CORS `allow_origins=["*"]` con `allow_credentials=True`** (combinación inválida/insegura) | `infra/api/app.py:18-24`. |
| S4 | 🟠 | **`/contact` sin autenticación** → relay de email vía Resend abusable (spam) | `infra/api/app.py:87-118` + ruta pública en `index.php` con CORS `*`. Sin rate-limit ni captcha. |
| S5 | 🟠 | **Trivy nunca bloquea**: ante CVE crítica imprime “MODO DEMO” y `return 0` | `scripts/funciones/seguridad.sh:16-23`. El README la vende como control de despliegue → **falso sentido de seguridad**. Además no se invoca desde `deploy.sh`. |
| S6 | 🟠 | **Chequeo de `API_TOKEN` inseguro no aborta** (el `exit(1)` está comentado) | `infra/api/app.py:27-31`. |
| S7 | 🟡 | **Permisos `0777`** en `infra/authelia/config/` y en `configuration.yml`/`users.yml` (contienen secretos y hashes) | `ls -la infra/authelia/config`. `db.sqlite3` legible. |
| S8 | 🟡 | **Socket Docker montado completo** en API y Portainer (= root en host) | `infra/docker-compose.yml:24,192`. Ya reconocido como pendiente (docker-socket-proxy). |
| S9 | 🟡 | **API genera hashes ejecutando `docker run authelia/authelia:latest`** por petición | `app.py:140-143`. Coste/latencia altos y superficie (pull de `:latest`, acceso al socket). |
| S10 | ⚪ | Hash MD5 como *fallback* si no hay `php` en `crear_usuario_admin` | `db.sh:129`. Ruta poco probable pero presente. |

### 4.2 Fiabilidad y operación

| # | Sev | Hallazgo | Evidencia |
|---|-----|----------|-----------|
| O1 | 🟠 | **0/17 plantillas con healthcheck** y **0/17 con límites de CPU/RAM** | `catalogo/*/docker-compose.tpl`. Sin protección OOM ni *self-healing*; riesgo de *noisy neighbor* en host compartido. |
| O2 | ✅ | **RESUELTO (2026-06-05)** — antes: `domain_regex` por empresa *hardcodeado* (solo `panaderia`, `btravel`); empresas nuevas (`fruteria`, `empresa01`) sin regla → `deny`/403. Ahora: **una única regla genérica** con grupo de captura nombrado `(?P<Group>...)` + asignación automática de `group:<empresa>` a cada usuario desde el dashboard. Escala a toda empresa futura sin editar Authelia. | Ver sección 6. `infra/authelia/config/configuration.yml`, `infra/admin-dashboard/usuarios.php`. |
| O3 | 🟡 | **Comprobación de puerto con `lsof`** que no ve contenedores (no publican en host) → la liveness real depende solo del registro `.txt` | `scripts/funciones/puertos.sh:16`. Doc dice `ss -tlnp`. |
| O4 | 🟡 | **Colisión de “puerto” en registro**: `panaderia:mariadb:8100` y `fruteria:mariadb:8100` | `scripts/databases/servicios.txt`. Inocuo hoy (mariadb no publica), pero el asignador puede confundirse. |
| O5 | ⚪ | `watchtower_global` **unhealthy** corriendo sin propósito declarado | `docker ps`. |

### 4.3 Reproducibilidad / cadena de suministro

| # | Sev | Hallazgo | Evidencia |
|---|-----|----------|-----------|
| R1 | 🟠 | **Tags `:latest` generalizados** (authelia, cloudflared, NPM, redis, wordpress, mariadb, prestashop, gitea…) **+ Watchtower activo** = updates automáticos no reproducibles ni auditables | `infra/docker-compose.yml`, `catalogo/*`, `docker ps`. Un push upstream puede romper o introducir CVE en cualquier momento. |
| R2 | ⚪ | Sin *lockfile*/digests (`@sha256`) de imágenes | idem. |

### 4.4 Deriva documentación ↔ realidad (gobernanza)

| # | Sev | Hallazgo |
|---|-----|----------|
| D1 | 🟠 | `SEGURIDAD_REMEDIACION.md` afirma que `dashy`, `fail2ban` y `watchtower` fueron **eliminados**; `dashy_portal` y `watchtower_global` **están corriendo**. La documentación de seguridad miente respecto al estado real. |
| D2 | 🟡 | README documenta **4** servicios de catálogo; existen **17**. |
| D3 | 🟡 | README/instalación con inconsistencias: `git clone … && cd SaaS-multiempresa-ASIR`, `DATA_DIR=/srv` (el motor usa `PROYECTO_ROOT/data`), `ss -tlnp` vs `lsof` real. |

### 4.5 Calidad de código / deuda técnica

| # | Sev | Hallazgo |
|---|-----|----------|
| C1 | 🟡 | **Sin tests automatizados reales**: `scripts/test.sh` es un guion manual que despliega de verdad (`testco/wordpress`), sin teardown ni asserts aislados. No hay CI. |
| C2 | 🟡 | Deuda en `users_db` ya identificada en `docs/MEJORAS.md`: redundancia `usuarios.empresa` vs `empresas.nombre` y `rol` vs `es_admin`; faltan índices en `access_logs`. |
| C3 | ⚪ | **Propiedad mixta** de credenciales (`root` vs `oscar`) porque la API (contenedor root) crea ficheros que luego el motor (host, usuario `oscar`) no puede gestionar. Fricción operativa. |
| C4 | ⚪ | `access_logs` definida pero sin uso visible (no se registran accesos al panel). |

### 4.6 Datos / estado

| # | Sev | Hallazgo |
|---|-----|----------|
| G1 | 🟡 | **Datos huérfanos en disco** de tenants inactivos: `data/{btravel,testco,test_env,martincodax}` y credenciales asociadas → secretos en reposo de servicios ya no usados. |
| G2 | ⚪ | Backups (`infra/backups/`) existen (backup/restore/cleanup) pero conviene verificar que el **cron** está activo y que `restore.sh` se ha probado (DR no validado). |

## 5. Plan de remediación priorizado

### P0 — Crítico (hacer ya; bajo esfuerzo, alto impacto)
1. **S2** — Verificar en `infra_users_db` si existe `admin/password`; eliminar o rotar y quitar el seed de `init.sql` (o cambiarlo por placeholder forzado en primer arranque).
2. **S1** — Parametrizar `db.sh`: pasar valores vía `mysql ... -e` con *here-doc* y variables escapadas, o mejor usar entrada por `--defaults`/STDIN; como mínimo validar nombres dentro de `db.sh` (no confiar en el llamante).
3. **D1 + O5** — Decidir: o se eliminan `dashy` y `watchtower` (coherencia con la doc), o se actualiza `SEGURIDAD_REMEDIACION.md`. Recomendado **eliminar Watchtower** (ver R1).
4. **S6** — Reactivar el aborto por `API_TOKEN` inseguro/ausente en `app.py`.

### P1 — Alto (esta o próxima iteración)
5. **R1** — Eliminar Watchtower y **fijar versiones** de imágenes (pin a tag mayor.menor; idealmente `@sha256`). Empezar por la infra global.
6. **S3 + S4** — Restringir CORS a orígenes conocidos (panel/landing) y proteger `/contact` con rate-limit + captcha/origen permitido.
7. **S5** — O se cablea Trivy en `deploy.sh` con bloqueo real (configurable), o se reescribe el README para no prometer un control que no existe.
8. **O1** — Añadir `healthcheck` y `mem_limit`/`cpus` (o `deploy.resources`) a las plantillas de catálogo (al menos WordPress, Nextcloud, Gitea, MariaDB).
9. ~~**O2** — Automatizar el alta de reglas Authelia por empresa~~ ✅ **HECHO (2026-06-05).** Implementado con `domain_regex` genérico y grupo de captura nombrado (ver sección 6); `fruteria`/`empresa01` y futuras funcionan sin edición manual.

### P2 — Medio / mantenimiento
10. **S7** — `chmod 750` (o 700) en `infra/authelia/config` y `640` en ficheros; sacar secretos de `configuration.yml` versionable.
11. **S8/S9** — Introducir `docker-socket-proxy` (ya en roadmap) y reemplazar el `docker run authelia` por la librería/CLI local de hashing.
12. **D2/D3 + C2** — Actualizar README (17 servicios, rutas reales) y aplicar las mejoras de `users_db` (`docs/MEJORAS.md`).
13. **C1** — Tests aislados con teardown (`testco` efímero) y, si procede, un workflow CI mínimo (lint Bash con `shellcheck`, `docker compose config`).
14. **G1/G2** — Limpiar `data/` huérfano (con backup previo) y validar el cron de backups + un *restore drill*.

## 6. Cambios aplicados (2026-06-05)

### 6.1 Aislamiento multi-tenant en Authelia (resuelve O2)
**Problema detectado en pruebas:** un usuario creado desde el panel para una empresa sin regla *hardcodeada* (`frutero`/`fruteria`) recibía **403 Forbidden** al abrir sus servicios (log: `Access to 'https://wordpress-fruteria.tensaas.es/' is forbidden to user 'frutero'`). Causa: las reglas `access_control` solo cubrían `panaderia` y `btravel`, y además usaban `subject: group:users` (sin aislamiento real entre tenants).

**Solución (3 cambios):**
1. **`infra/authelia/config/configuration.yml`** — sustituidas las reglas por-empresa por **una única regla genérica** con grupo de captura nombrado:
   ```yaml
   - domain_regex:
       - "^[a-z0-9]+-(?P<Group>[a-z0-9]+)\\.tensaas\\.es$"
     policy: one_factor
   ```
   Authelia exige que el usuario pertenezca al grupo igual a la `<empresa>` capturada del dominio `<servicio>-<empresa>.tensaas.es`. Aislamiento por tenant **automático para cualquier empresa presente o futura**, sin volver a editar Authelia.
2. **`infra/admin-dashboard/usuarios.php`** — `syncWithAuthelia()` ahora asigna `group:<empresa>` (en minúsculas, buscado por `empresa_id`) a cada usuario no-admin al crearlo. Los admins globales (`es_admin=1`) siguen en `group:admins` (regla maestra 2FA).
3. **`infra/authelia/config/users.yml`** — añadido `fruteria` al usuario `frutero` ya existente.

**Limitación eliminada:** ya no hace falta una regla por empresa; el motor no necesita generar `access_control`.

### 6.2 Higiene de usuarios
- **BD (`users_db.usuarios`)**: depurada a los usuarios de prueba vigentes (solo `SaaS_Global`: `superadmin`, `Admin`; más `frutero` creado en la prueba del panel).
- **Authelia (`users.yml`)**: eliminados usuarios obsoletos que seguían en Authelia tras borrarse de la BD por SQL directo (`juan_panaderia`, `maria`, `admin_btravel`, `usuprueba`) — el `DELETE` por SQL no invoca `removeFromAuthelia`. Quedan `admin` (SSO global de Óscar) y `frutero`.

> Nota relacionada (S2): el seed `admin/password` de `init.sql` **no** está presente en la BD viva (fue sustituido por `Admin`/`superadmin`); pendiente aún quitar el seed del script para despliegues nuevos.

## Verificación (cómo comprobar cada cosa)

- **Estado real:** `docker ps -a`, `docker network ls`, `cat scripts/databases/servicios.txt`, `tail scripts/logs/sync.log`.
- **S2:** `docker exec infra_users_db mysql -u root -p users_db -e "SELECT usuario,es_admin FROM usuarios WHERE usuario='admin';"` y probar login en el panel.
- **S1/S4/S3:** revisión de código + prueba dirigida (entrada con comilla en nombre / petición `/contact` desde origen no permitido).
- **R1:** `docker inspect` de imágenes para confirmar pinning; confirmar ausencia de `watchtower`.
- **O1:** `docker inspect --format '{{.State.Health.Status}}'` y `docker stats` tras añadir límites.
- **O2:** alta de empresa nueva de prueba y verificación de que su usuario accede a su subdominio sin tocar Authelia.
- Tras cualquier cambio: `DRY_RUN=true ./scripts/sync.sh` y `docker compose -f infra/docker-compose.yml config -q`.

> Nota: este entregable es **diagnóstico + roadmap**, no modifica código. La implementación de los P0/P1 se abordaría en iteraciones posteriores si el usuario lo aprueba.
