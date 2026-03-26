# TESTING.md - Validacion del Sistema

## Proposito

Documentacion de como validar que el sistema funciona correctamente, especialmente:
1. Dependencias se instalan automaticamente
2. Lista, credenciales, y destroy funcionan
3. Integridad de BD después de operaciones

---

## Test automatico

### Ejecutar suite de tests

```bash
./test.sh
```

**Que hace:**
1. Lista servicios actuales
2. Deploy de WordPress (debe instalar MariaDB automaticamente)
3. Verifica que MariaDB está en BD
4. Verifica que WordPress está en BD
5. List muestra ambos servicios
6. Get-credentials obtiene datos de WordPress
7. Destroy elimina servicio
8. Verifica que fue eliminado de BD

**Salida esperada:**
```
====== TESTS DE VALIDACION ======

[OK] TEST 1: Listar servicios (BD inicial)
[OK] TEST 2: Deploy WordPress con dependencias automaticas
[OK] TEST 3: Verificar que MariaDB se instalo automaticamente
[OK] TEST 4: Verificar que WordPress se instalo
[OK] TEST 5: List debe mostrar mariadb + wordpress
[OK] TEST 6: Get-credentials debe mostrar credenciales
[OK] TEST 7: Destroy (eliminacion segura)
[OK] TEST 8: Verificar que WordPress fue eliminado de BD

====== RESULTADOS ======
Pasados: 8
Fallos: 0

[OK] TODOS LOS TESTS PASARON
```

---

## Test manual paso-a-paso

### Escenario 1: WordPress con dependencia automatica

**Objetivo:** Verificar que WordPress se despliega automaticamente con MariaDB

```bash
# 1. Ver estado inicial
./list.sh

# 2. Desplegar WordPress (debe preguntar por dependencias o instalarlas)
./deploy.sh testco wordpress

# Esperado:
# - Detecta que WordPress requiere mariadb
# - Instala mariadb para testco
# - Instala wordpress para testco
```

**Verificacion:**
```bash
# 3. Ver que ambos están listados
./list.sh testco

# Esperado:
# testco    wordpress        8042      running
# testco    mariadb          8043      running

# 4. Obtener credenciales
./get-credentials.sh testco wordpress

# Esperado: Muestra usuario y password
```

### Escenario 2: Comportamiento de lista

**Objetivo:** Verificar que list.sh funciona en diferentes formatos

```bash
# Lista toda: formato tabla
./list.sh

# Lista solo empresa: formato tabla
./list.sh testco

# Lista en JSON
./list.sh testco json

# Lista en CSV
./list.sh testco csv
```

**Esperado:**
- Tabla: Columnas empresa, servicio, puerto, estado
- JSON: Array de objetos con URL incluida
- CSV: Encabezado + datos separados por coma

### Escenario 3: Eliminacion segura

**Objetivo:** Verificar que destroy hace backup y limpia bien

```bash
# 1. Ver servicios antes
./list.sh testco

# 2. Eliminar (pide confirmacion)
./destroy.sh testco wordpress

# Esperado:
# - Pide confirmacion (digite Y)
# - Dice que hace backup
# - Para contenedores
# - Elimina datos
# - Actualiza BD

# 3. Ver que fue eliminado
./list.sh testco

# Esperado: WordPress ya no está en lista
```

**Verificar que backup se hizo:**
```bash
ls -lh /srv/backups/testco/wordpress/

# Esperado: archivo backup_YYYYMMDD_HHMMSS.tar.gz
```

### Escenario 4: Credenciales recuperables

**Objetivo:** Verificar que las credenciales se guardan y recuperan

```bash
# 1. Deploy genera credenciales
./deploy.sh testco nginx

# 2. Credenciales se guardaron
cat scripts/databases/credentials/testco.nginx

# Esperado: Archivo con usuario y password

# 3. Get-credentials las obtiene
./get-credentials.sh testco nginx

# Esperado: Mismos usuario y password mostrados formateados
```

---

## Chequeos de integridad

### Archivo de BD

```bash
# Ver servicios registrados
cat scripts/databases/servicios.txt

# Formato esperado:
# empresa:servicio:puerto:status
# testco:wordpress:8042:running
# testco:mariadb:8043:running

# Ver empresas registradas
cat scripts/databases/empresas.txt

# Esperado:
# testco
```

### Estado de contenedores

```bash
# Ver contenedores Docker
docker ps

# Esperado: Contenedores llamados <empresa>_<servicio>_1
# testco_wordpress_1
# testco_mariadb_1

# Ver estado especifico
docker inspect testco_wordpress_1
```

### Credenciales

```bash
# Ver credenciales guardadas
ls -lh scripts/databases/credentials/

# Ver contenido
cat scripts/databases/credentials/testco.wordpress

# Esperado:
# usuario=testco_wordpress_user
# password=abc123...

# Permisos: 600 (solo lectura para propietario)
ls -l scripts/databases/credentials/testco.wordpress
# Esperado: -rw------- (600)
```

### Logs

```bash
# Ver logs de operaciones
ls scripts/logs/

# Ver último log
tail -f scripts/logs/*deploy*.log

# Ver estructura
cat scripts/logs/testco_wordpress_deploy_*.log
```

---

## Casos de error esperados

### Error 1: Servicio que no existe en catálogo

```bash
./deploy.sh testco servicioquenoexiste

# Esperado:
# [ERROR] Servicio no existe: servicioquenoexiste
# [INFO] Disponibles: grafana mariadb nextcloud nginx ...
```

### Error 2: Falta parámetro

```bash
./deploy.sh testco

# Esperado:
# [ERROR] Parametros insuficientes
# [INFO] Uso: ./deploy.sh <empresa> <servicio>
```

### Error 3: Servicio ya existe

```bash
./deploy.sh testco wordpress
# Primera vez: OK
./deploy.sh testco wordpress
# Segunda vez: Esperado:
# [WARN] Servicio ya existe para testco/wordpress
# [OK] Servicio ya está activo
```

### Error 4: Get-credentials sin servicio

```bash
./get-credentials.sh testco servicioquenoexiste

# Esperado:
# [ERROR] Servicio no encontrado: testco/servicioquenoexiste
```

### Error 5: Destroy cancela si usuario rechaza

```bash
./destroy.sh testco wordpress
# Responder N en confirmacion

# Esperado:
# [WARN] Operacion cancelada
# Nada se elimina
```

---

## Validacion de integridad post-operacion

Después de cada operación importante, verificar:

### Post-deploy
- [ ] Contenedor está corriendo: `docker ps | grep <servicio>`
- [ ] BD registra empresa: `grep ^<empresa>$ scripts/databases/empresas.txt`
- [ ] BD registra servicio: `grep ^<empresa>:<servicio>: scripts/databases/servicios.txt`
- [ ] Credenciales guardadas: `ls scripts/databases/credentials/<empresa>.<servicio>`
- [ ] Puerto asignado es libre: `lsof -i :<puerto>`
- [ ] Red Docker creada: `docker network ls | grep <empresa>`

### Post-destroy
- [ ] Contenedor eliminado: `docker ps | grep -v <servicio>`
- [ ] BD limpia: `! grep ^<empresa>:<servicio>: scripts/databases/servicios.txt`
- [ ] Credenciales eliminadas: `! ls scripts/databases/credentials/<empresa>.<servicio>`
- [ ] Datos eliminados: `! ls -d /srv/<empresa>/<servicio>`
- [ ] Red limpia si está vacía: `docker network ls | grep -v <empresa>`

---

## Comandos de debug útiles

```bash
# Ver todo en BD
cat scripts/databases/servicios.txt | column -t -s:

# Ver credenciales
cat scripts/databases/credentials/<empresa>.<servicio>

# Ver logs de deploy
tail -50 scripts/logs/*deploy*.log

# Ver estado Docker
docker compose -f /srv/<empresa>/<servicio>/docker-compose.yml ps

# Entrar al contenedor
docker exec -it <empresa>_<servicio>_1 bash

# Ver logs del contenedor
docker logs -f <empresa>_<servicio>_1

# Ver red Docker
docker network inspect <empresa>_net
```

---

## Checklist antes de defensa

- [ ] test.sh pasa 8/8 tests
- [ ] list.sh muestra servicios formateados
- [ ] get-credentials.sh muestra datos correctos
- [ ] destroy.sh elimina correctamente
- [ ] WordPress con MariaDB se despliega automaticamente
- [ ] BD mantiene integridad después de operaciones
- [ ] Credenciales se guardan y recuperan
- [ ] Backups se crean antes de destroy
- [ ] Todos los logs están disponibles
