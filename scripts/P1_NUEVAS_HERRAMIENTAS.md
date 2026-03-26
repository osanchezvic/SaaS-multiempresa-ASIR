# Scripts P1 - Nuevas Herramientas

## Descripcion

Implementacion de herramientas críticas para gestión de servicios:
- `list.sh` - Listar empresas y servicios desplegados
- `get-credentials.sh` - Mostrar credenciales guardadas
- `destroy.sh` - Eliminar servicios con backup automatico
- Validación automática de dependencias

---

## Scripts nuevos

### 1. list.sh - Listar servicios

```bash
# Listar todos los servicios (formato tabla)
./list.sh

# Listar solo empresa específica
./list.sh acme

# Listar en formato JSON
./list.sh acme json

# Listar en formato CSV
./list.sh "" csv
```

**Salida tabla:**
```
Empresa     Servicio           Puerto    Estado
=========   ================   =======   ===========
acme        wordpress          8042      running
acme        mariadb            8043      running
beta        nginx              8044      running
```

**Salida JSON:**
```json
[
    {
      "empresa": "acme",
      "servicio": "wordpress",
      "puerto": "8042",
      "estado": "running",
      "url": "http://localhost:8042"
    }
]
```

---

### 2. get-credentials.sh - Mostrar credenciales

```bash
# Mostrar credenciales de un servicio
./get-credentials.sh acme wordpress
```

**Salida:**
```
[OK] Credenciales de acme/wordpress:

====================================================
usuario              : acme_wordpress_user
password             : abc123def456...
====================================================
```

---

### 3. destroy.sh - Eliminar servicios

```bash
# Eliminar un servicio (con confirmación)
./destroy.sh acme wordpress
```

**Funciones:**
- Pide confirmación antes de eliminar
- Hace backup automatico antes de destruir
- Elimina contenedores y datos
- Limpia red Docker si está vacía
- Elimina credenciales guardadas
- Actualiza BD de servicios

---

## Validacion automatica de dependencias

### Como funciona

1. Cuando haces deploy de un servicio, se verifica su config.yml
2. Si el servicio tiene "dependencias:" definidas, se validan
3. Si un servicio dependiente falta (ej: WordPress sin MariaDB):
   - Sistema muestra advertencia
   - Pregunta si quieres instalarlo automaticamente
   - Si aceptas: se despliega la dependencia primero
   - Después se despliega el servicio principal

### Ejemplo: Desplegar WordPress sin MariaDB

```bash
./deploy.sh acme wordpress
```

**Salida:**
```
[OK] Iniciando deploy de acme/wordpress
[OK] Verificando dependencias de wordpress...
[WARN] Dependencia FALTA: acme/mariadb
[OK] Instalando dependencia: mariadb...
[OK] Dependencia instalada: acme/mariadb
[OK] Desplegando wordpress...
```

### Servicios con dependencias conocidas

Desde config.yml:
- **wordpress** require mariadb
- **phpmyadmin** require mariadb
- **nextcloud** require mariadb
- (otros servicios pueden tener sus propias dependencias)

---

## Integracion deploy -> destroy

### Flujo completo

```bash
# 1. Desplegar
./deploy.sh acme wordpress
# Resultado:
# - Crea BD automaticamente si falta
# - Despliega WordPress
# - Guarda credenciales

# 2. Ver que se desplegó
./list.sh acme

# 3. Obtener credenciales (si las olvidaste)
./get-credentials.sh acme wordpress

# 4. Eliminar cuando no lo necesites
./destroy.sh acme wordpress
# - Hace backup antes de destruir
# - Pide confirmación
# - Limpia todo (contenedores, datos, credenciales)
```

---

## Cambios en validaciones.sh

Se agregaron funciones nuevas:

- `obtener_dependencias()` - Lee config.yml y extrae lista de dependencias
- `validar_dependencias_auto()` - Verifica y gestiona dependencias automaticamente
- `validar_pre_deploy()` - Ahora incluye validacion de dependencias
- `validar_post_deploy()` - Espera a que contenedor esté running

**Antes:**
- No validaba dependencias
- Si WordPress sin MariaDB -> fallaba a mitad del deploy

**Ahora:**
- Detecta automáticamente qué necesita cada servicio
- Lo instala si falta
- Garantiza que el deploy funcione

---

## Cambios en logging.sh

Se agregaron alias de compatibilidad:

```bash
# Antes (solo estos funcionaban)
echo_info
echo_error
echo_warn
echo_debug

# Ahora (ambos funcionan)
log_info      # alias de echo_info
log_error     # alias de echo_error
log_warn      # alias de echo_warn
log_debug     # alias de echo_debug
log_success   # alias de echo_success
log_failed    # alias de echo_error

# Nueva función
init_log()                  # Inicializa directorio de logs
wait_container_healthy()    # Espera a que contenedor esté running
```

---

## Próximos pasos (P2)

- [ ] Panel web para desplegar servicios desde navegador
- [ ] Sync de backups a S3/NAS
- [ ] Métricas por empresa (CPU/RAM)
- [ ] Rollback automático si servicio falla
- [ ] Notificaciones Slack
