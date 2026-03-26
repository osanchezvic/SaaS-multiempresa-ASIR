# IaaS Multiempresa ASIR - TFC

**Proyecto de Fin de Ciclo (TFC)** para módulo de ASIR.

Sistema de despliegue automatizado de servicios Docker para múltiples empresas con gestión robusta de puertos, credenciales seguras, backups automaticos y validación de dependencias.

---

## Inicio rápido

```bash
# 1. Desplegar WordPress (instala MariaDB automaticamente)
cd scripts
./deploy.sh miempresa wordpress

# 2. Ver servicios desplegados
./list.sh miempresa

# 3. Obtener credenciales
./get-credentials.sh miempresa wordpress

# 4. Eliminar (con backup)
./destroy.sh miempresa wordpress
```

---

## Estructura

```
|-- scripts/                 # Orquestación y deploy
|   |-- deploy.sh
|   |-- destroy.sh
|   |-- list.sh
|   |-- get-credentials.sh
|   |-- test.sh
|   |-- funciones/           # Módulos reutilizables
|   |   |-- logging.sh
|   |   |-- db.sh
|   |   |-- puertos.sh
|   |   |-- utils.sh
|   |   |-- validaciones.sh
|   |-- databases/           # Estado y credenciales
|   |-- logs/                # Auditoria
|   |-- P0_COMPLETADO.md
|   |-- P1_NUEVAS_HERRAMIENTAS.md
|   |-- TESTING.md
|-- catalogo/                # 14 servicios listos
|   |-- wordpress/
|   |-- mariadb/
|   |-- grafana/
|   |-- nginx/
|   |-- prometheus/
|   |-- portainer/
|   |   (y 8 mas)
|-- infra/                   # Servicios globales
|   |-- docker-compose.yml
|   |-- deploy-infra.sh
|   |-- backups/
|   |-- portainer/
|   |-- monitorizacion/
|   |-- proxy/
|   |-- watchtower/
|   |-- seguridad/
|-- docs/
|-- ESTADO_PROYECTO.md       # Resumen completo
```

---

## Caracteristicas principales

### Validacion automatica de dependencias

WordPress necesita MariaDB? El sistema lo instala automaticamente.

```bash
./deploy.sh acme wordpress

# Resultado:
# [WARN] Dependencia FALTA: acme/mariadb
# [OK] Instalando dependencia: mariadb...
# [OK] Dependencia instalada: acme/mariadb
# [OK] Desplegando wordpress...
```

### Multi-empresa con aislamiento

Cada empresa tiene:
- Servicios independientes
- Red Docker aislada
- Puertos sin colisiones
- Credenciales propias

### Gestion segura

- Credenciales con permisos 600
- Backups automaticos antes de delete
- BD de integridad para auditoria
- Logs de todas las operaciones

### Testing automatico

Suite de 8 tests que valida:
- Deploy con dependencias
- List en multiples formatos
- Get-credentials
- Destroy seguro
- Integridad de BD

```bash
./test.sh
# Resultado: 8 PASS, 0 FAIL
```

---

## Comandos principales

### Deploy

```bash
# Desplegar un servicio (con dependencias automaticas)
./scripts/deploy.sh <empresa> <servicio>

# Ejemplo
./scripts/deploy.sh miempresa wordpress
```

### Lista

```bash
# Ver todos los servicios
./scripts/list.sh

# Ver servicios de empresa especifica
./scripts/list.sh miempresa

# Ver en JSON
./scripts/list.sh miempresa json

# Ver en CSV
./scripts/list.sh "" csv
```

### Credenciales

```bash
# Mostrar credenciales guardadas
./scripts/get-credentials.sh <empresa> <servicio>

# Ejemplo
./scripts/get-credentials.sh miempresa wordpress
```

### Destroy

```bash
# Eliminar servicio (con confirmacion y backup)
./scripts/destroy.sh <empresa> <servicio>

# Ejemplo
./scripts/destroy.sh miempresa wordpress
```

### Testing

```bash
# Ejecutar suite automatica
./scripts/test.sh
```

---

## Documentacion

- **ESTADO_PROYECTO.md** - Resumen ejecutivo, metricas, checklist
- **scripts/P0_COMPLETADO.md** - Fase 0: logging, BD, puertos, credenciales
- **scripts/P1_NUEVAS_HERRAMIENTAS.md** - Fase 1: list, get-creds, destroy
- **scripts/TESTING.md** - Como validar el proyecto

---

## Servicios disponibles en catálogo

1. WordPress (con tema, plugins)
2. MariaDB
3. Nginx
4. Grafana
5. Prometheus
6. Node-exporter
7. Portainer
8. Uptime-Kuma
9. Vaultwarden
10. Redis
11. PhpMyAdmin
12. Zabbix
13. Nextcloud
14. VPN

---

## Infraestructura global

Servicios siempre activos (compartidos):
- **Portainer** - Gestor Docker web (puerto 9000)
- **Grafana** - Dashboards (puerto 3000)
- **Prometheus** - Metricas
- **Node-exporter** - Datos del host
- **Nginx Proxy Manager** - Proxy reverso (puerto 80/443)
- **Watchtower** - Auto-update de imagenes
- **Fail2ban** - Proteccion fuerza bruta

Deploy:
```bash
cd infra
./deploy-infra.sh start
```

---

## Flujo de trabajo

1. **Deploy empresa + servicio:**
   ```bash
   ./deploy.sh acme wordpress
   ```
   - Detecta dependencias (MariaDB)
   - Las instala automaticamente
   - Genera credenciales seguras
   - Despliega servicios

2. **Ver estado:**
   ```bash
   ./list.sh acme
   ```
   - Muestra servicios, puertos, estado

3. **Usar servicio:**
   - WordPress en http://localhost:{puerto}
   - Credenciales: `./get-credentials.sh acme wordpress`

4. **Backup/Restore:**
   - Automatico antes de destroy
   - Manual: `infra/backups/backup.sh acme wordpress`

5. **Eliminar:**
   ```bash
   ./destroy.sh acme wordpress
   ```
   - Hace backup
   - Pide confirmacion
   - Limpia todo (contenedores, datos, credenciales)

---

## Testing

### Test automatico (recomendado)

```bash
cd scripts
./test.sh

# Valida:
# ✓ Deploy WordPress con MariaDB automatica
# ✓ List muestra servicios
# ✓ Get-credentials obtiene datos
# ✓ Destroy elimina correctamente
# ✓ BD mantiene integridad
```

### Test manual paso-a-paso

Ver `scripts/TESTING.md` para casos específicos:
- Escenario 1: WordPress + dependencia automatica
- Escenario 2: Comportamiento de lista
- Escenario 3: Eliminacion segura
- Escenario 4: Credenciales recuperables

---

## Nivel ASIR

Este proyecto es apropiado para TFC de ASIR porque:

1. **Comprensible:**
   - Bash simple (sin jq/awk complejos)
   - Funciones modularizadas
   - Logs claros

2. **Explicable:**
   - Arquitectura clara (multiempresa)
   - Cada decisión justificable
   - Casos de uso reales

3. **Defendible:**
   - Testing automatico
   - Documentacion completa
   - Manejo de errores robusto

4. **Escalable:**
   - Fácil agregar servicios al catálogo
   - Fácil agregarempresas
   - Sistema modular

---

## Requisitos

- Docker (versión 20+)
- Docker Compose (versión 2+)
- Bash 4.0+
- Linux (probado en Ubuntu 20+, Debian 11+)

---

## Instalacion

1. Clona el proyecto:
   ```bash
   git clone <repo>
   cd IaaS-multiempresa-ASIR
   ```

2. Verifica requisitos:
   ```bash
   docker --version
   docker compose --version
   bash --version
   ```

3. Prueba con test:
   ```bash
   cd scripts
   ./test.sh
   ```

---

## Status

**LISTO PARA DEFENSA ASIR** ✓

- P0 (base): 100%
- P1 (herramientas): 100%
- Testing: 8/8 tests PASS
- Documentacion: Completa
- Complejidad: Nivel ASIR

---

## Contacto / Defensa

Este proyecto fue creado por: **Oscar Sánchez Víctor**

Para defensa, consulta:
- `ESTADO_PROYECTO.md` - Resumen ejecutivo
- `scripts/TESTING.md` - Como validar
- `scripts/P0_COMPLETADO.md` - Fase 0
- `scripts/P1_NUEVAS_HERRAMIENTAS.md` - Fase 1
