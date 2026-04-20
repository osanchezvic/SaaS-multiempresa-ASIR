# EXPLICACIÓN SIMPLIFICADA DEL PROYECTO - NIVEL ASIR

Este documento explica el proyecto de forma sencilla para que puedas entenderlo y defenderlo en tu examen de ASIR.

---

## 1. QUÉ HACE ESTE PROYECTO

Imagina que tienes varias empresas y quieres dar a cada una sus propios servicios web (WordPress, bases de datos, etc.) pero de forma separada y segura.

**Ejemplo:**
- Empresa A quiere WordPress
- Empresa B quiere WordPress + MariaDB
- Empresa C quiere Grafana

El proyecto te permite desplegar todo esto con UN SOLO COMANDO.

---

## 2. COMandos PRINCIPALES (LOS QUE USARÁS)

```bash
# 1. INSTALAR un servicio
./scripts/deploy.sh nombre_empresa nombre_servicio

# Ejemplo: instalar WordPress para la empresa "acme"
./scripts/deploy.sh acme wordpress

# 2. VER qué hay desplegado
./scripts/list.sh

# 3. VER las contraseñas
./scripts/get-credentials.sh acme wordpress

# 4. ELIMINAR un servicio (hace backup primero)
./scripts/destroy.sh acme wordpress
```

---

## 3. QUÉ ES EL JSON (Y POR QUÉ SE USA)

### Qué es JSON:
JSON es un formato para guardar datos de forma organizada. Es como una hoja de Excel pero en texto.

### Para qué sirve en este proyecto:
El JSON se usa para **guardar las contraseñas** de forma ordenada.

**Ejemplo de cómo se ve un JSON de credenciales:**
```json
{
  "db_name": "acme_db",
  "db_user": "acme_user",
  "db_password": "abc123def456",
  "admin_user": "admin",
  "admin_password": "xyz789",
  "puerto": "8042",
  "created_at": "2026-04-07T12:00:00Z"
}
```

### Por qué no te preocupa:
**NO NECESITAS MANEJAR JSON DIRECTAMENTE.** El script lo hace solo:
- Cuando instalas, genera el JSON automáticamente
- Cuando quieres ver contraseñas, el script lo lee y te lo muestra bonito

### Dónde se guarda:
En `scripts/databases/credentials/` hay archivos como:
- `acme.wordpress` (contiene el JSON)
- `acme.mariadb` (contiene el JSON)

---

## 4. QUÉ ES EL YAML (config.yml)

YAML es como JSON pero más fácil de leer. Se usa para **configurar los servicios**.

**Ejemplo - WordPress (catalogo/wordpress/config.yml):**
```yaml
nombre: wordpress
descripcion: CMS WordPress con base de datos MariaDB.
puerto_por_defecto: 8082
volumenes:
  - wordpress
dependencias:
  - mariadb
```

**Qué significa cada línea:**
- `nombre:` - Cómo se llama el servicio
- `descripcion:` - Qué es
- `puerto_por_defecto:` - Puerto que usará por defecto
- `volumenes:` - Qué carpetas compartirá con el ordenador
- `dependencias:` - Otros servicios que necesita (WordPress necesita MariaDB)

---

## 5. CÓMO FUNCIONA EL SISTEMA DE DEPENDENCIAS

Esto es una de las partes más inteligentes del proyecto.

### El problema:
WordPress necesita una base de datos (MariaDB) para funcionar. Antes había que instalarla a mano.

### La solución:
El sistema **detecta automáticamente** qué necesita cada servicio y lo instala solo.

**Paso a paso cuando ejecutas `./deploy.sh acme wordpress`:**

1. El script lee `catalogo/wordpress/config.yml`
2. Ve que tiene `dependencias: - mariadb`
3. Pregunta: "¿Ya está mariadb instalado para acme?"
4. Si no: ¡Lo instala automáticamente!
5. Luego instala WordPress
6. ¡Listo! WordPress funciona porque tiene su base de datos

### Otros servicios con dependencias:
- Nextcloud → necesita MariaDB
- PhpMyAdmin → necesita MariaDB

---

## 6. QUÉ SON LOS TEMPLATES (plantillas)

Los templates son **modelos** que el script adapta para cada empresa.

**Problema antes:**
¿cómo hacer un docker-compose.yml diferente para cada empresa?

**Solución:**
Usar plantillas con "huecos" que se rellenan automáticamente.

**Ejemplo - docker-compose.tpl (plantilla):**
```yaml
services:
  {{EMPRESA}}_wordpress:
    ports:
      - "{{PUERTO}}:80"
```

**Cuando ejecutas `./deploy.sh acme wordpress`:**
- `{{EMPRESA}}` → se convierte en `acme`
- `{{PUERTO}}` → se convierte en `8042`

El resultado es:
```yaml
services:
  acme_wordpress:
    ports:
      - "8042:80"
```

Esto se llama **sustitución de texto** - es como completar huecos en una plantilla.

---

## 7. LA BASE DE DATOS (DB) DEL SISTEMA

El proyecto ha evolucionado a una arquitectura con base de datos real (MariaDB) para gestionar los usuarios y empresas, mejorando la seguridad y permitiendo el control de acceso basado en roles (RBAC).

**Tabla `usuarios`:**
- Almacena: `id`, `usuario`, `hash_password`, `empresa_id` (relación), `es_admin`, `estado`.
- Permite diferenciar entre administradores globales y administradores de empresa (tenants).

**Control de Acceso (RBAC):**
- **Administradores Globales (`es_admin` = 1):** Acceso total a todas las empresas y estadísticas del sistema.
- **Administradores de Empresa (`es_admin` = 0, `empresa_id` = ID):** Acceso restringido únicamente a los datos de su propia empresa.

---


## 8. QUÉ ES DOCKER Y DOCKER COMPOSE (RESUMEN)

### Docker:
Es como una "caja mágica" que contiene un programa con todo lo que necesita para funcionar (el programa, las librerías, la configuración). Se llama **contenedor**.

### Docker Compose:
Un archivo que dice cómo poner en marcha varioconenedores juntos. Por ejemplo, WordPress + MariaDB.

**En este proyecto:**
- Los templates en `catalogo/*/docker-compose.tpl` son los archivos Docker Compose
- El script los adapta y los despliega

---

## 9. ESTRUCTURA DE CARPETAS (SIMPLIFICADA)

```
SaaS-multiempresa-ASIR/
├── scripts/                    ← Los comandos que ejecutas
│   ├── deploy.sh              ← Instalar servicios
│   ├── list.sh                ← Ver qué hay instalado
│   ├── get-credentials.sh    ← Ver contraseñas
│   ├── destroy.sh             ← Eliminar servicios
│   └── funciones/             ← Código interno (no tocas)
│
├── catalogo/                   ← Catálogo de servicios disponibles
│   ├── wordpress/             ← Config de WordPress
│   ├── mariadb/               ← Config de MariaDB
│   └── ... (otros servicios)
│
└── infra/                     ← Servicios globales (Portainer, Grafana, etc.)
```

---

## 10. QUÉ TIENES QUE EXPLICAR EN LA DEFENSA

### Explica esto y tienes el examen aprobado:

**1. Arquitectura multiempresa:**
"Cada empresa tiene sus propios contenedores aislados. Uso redes Docker separadas para que no se mezclen los servicios."

**2. Sistema de dependencias:**
"Cuando instalo WordPress, el sistema lee su config.yml, ve que necesita MariaDB, y la instala automáticamente si no existe."

**3. Gestión de puertos:**
"Asigno puertos automáticamente del 8000-8999 para evitar conflictos."

**4. Seguridad:**
"Las contraseñas se guardan en JSON con permisos 600 (solo el propietario puede leerlas)."

**5. Facilidad de uso:**
"Con un solo comando instalo servicios completos: ./deploy.sh empresa servicio"

---

## 11. EJEMPLO PRÁCTICO DE EJECUCIÓN

```bash
# Ver servicios disponibles
ls catalogo/

# Instalar WordPress para "acme"
./scripts/deploy.sh acme wordpress

# Salida esperada:
# [INFO] Iniciando deploy de acme/wordpress
# [WARN] Dependencia FALTA: acme/mariadb
# [INFO] Instalando dependencia: mariadb...
# [OK] Dependencia instalada: acme/mariadb
# [OK] Desplegando wordpress...
# [OK] Servicio acme/wordpress en puerto 8042

# Ver lo instalado
./scripts/list.sh

# Ver contraseñas
./scripts/get-credentials.sh acme wordpress

# Eliminar (con backup automático)
./scripts/destroy.sh acme wordpress
```

---

## 12. RESUMEN RÁPIDO

| Concepto | Explicación simple |
|----------|-------------------|
| JSON | Formato para guardar datos organizados (contraseñas) |
| YAML | Formato fácil de leer para configurar servicios |
| Template | Modelo con huecos que se rellena automáticamente |
| Dependencias | Servicios que necesitan otros para funcionar |
| Docker | Contenedores con programas listos para usar |
| Redes aisladas | Cada empresa tiene su red Docker privada |

---

## 13. SI TE PREGUNTAN POR QUÉ NO USAS JSON DIRECTAMENTE

Puedes decir:

"Uso JSON internamente para guardar las contraseñas de forma estructurada, pero el usuariofinal no necesita verlo. Los scripts leen el JSON y le muestran la información de forma clara. Es como когда tienes un armario por dentro pero por fuera solo ves las puertas nice."

---

## 14. COMPROBAR QUE TODO FUNCIONA

```bash
# Ejecutar tests automáticos
cd scripts
./test.sh

# Debe mostrar: 8 PASS, 0 FAIL
```

Si tienes cualquier duda, recuerda: **el proyecto hace todo el trabajo automático. Tú solo ejecutas comandos simples.**