# Manual de Usuario — TenSaaS

**Para:** clientes y usuarios de los servicios contratados
**Última actualización:** 2026-06-05

> Bienvenido/a a **TenSaaS**. Esta guía explica, en lenguaje sencillo y sin tecnicismos, cómo acceder a tu panel, entrar en tus servicios de forma segura y resolver las dudas más habituales. No necesitas conocimientos técnicos para seguirla.

---

## 1. ¿Qué es TenSaaS?

TenSaaS es la plataforma desde la que tu empresa accede a sus herramientas digitales (tu web, tu almacenamiento en la nube, tu gestor de contraseñas, etc.). Todos tus servicios:

- están **aislados** y son privados de tu empresa,
- se abren desde una **dirección propia** con candado de seguridad (HTTPS),
- y se protegen con **inicio de sesión único y doble factor**, para que solo entren las personas autorizadas.

Cada servicio tiene su propia dirección con esta forma:

```
https://<servicio>-<tuempresa>.tensaas.es
```

Por ejemplo, la web de la empresa «panaderia» sería `https://wordpress-panaderia.tensaas.es`.

---

## 2. Tu primer acceso

### Paso 1 — Recibirás tus datos de acceso
El operador de la plataforma te entregará:
- tu **nombre de usuario**,
- una **contraseña inicial**,
- y el enlace a tu **panel**: `https://panel.tensaas.es`.

### Paso 2 — Configura el doble factor (2FA)
La primera vez que inicies sesión, el sistema (Authelia) te pedirá configurar un **segundo factor** de seguridad mediante una aplicación de autenticación en tu móvil:

1. Instala una app de autenticación: **Microsoft Authenticator**, **Google Authenticator** o similar.
2. En la pantalla de configuración, **escanea el código QR** que aparece.
3. La app empezará a generar un **código de 6 dígitos** que cambia cada 30 segundos.
4. Introduce ese código para confirmar.

> Guarda bien el acceso a tu app de autenticación: la necesitarás cada vez (o cada cierto tiempo) que inicies sesión.

### Paso 3 — Cambia tu contraseña
Por seguridad, cambia la contraseña inicial por una propia en cuanto entres por primera vez.

---

## 3. Iniciar sesión

1. Abre `https://panel.tensaas.es`.
2. Introduce tu **usuario** y **contraseña**.
3. Cuando se te pida, introduce el **código de 6 dígitos** de tu app de autenticación.
4. Entrarás en tu panel.

Una vez dentro, el inicio de sesión queda recordado durante un rato: podrás abrir varios servicios sin volver a escribir la contraseña. Por seguridad, la sesión **caduca** tras un periodo de inactividad y volverá a pedírtela.

---

## 4. Tu panel

Desde el panel puedes ver, de un vistazo:
- los **servicios** que tu empresa tiene contratados,
- su **estado** (activo / inactivo),
- y un botón para **abrir** cada uno.

### Abrir un servicio
Pulsa **«Abrir»** en el servicio que quieras usar. Se abrirá en tu navegador.
- Si tu sesión sigue activa, entrarás directamente.
- Si había caducado, el sistema te pedirá iniciar sesión una vez más (usuario + código del móvil) y después te llevará al servicio.

> Solo puedes abrir los servicios **de tu propia empresa**. Es normal y forma parte del aislamiento de seguridad: los servicios de otras empresas no son accesibles para ti.

---

## 5. Tus servicios (qué es cada uno)

Según tu plan, podrás tener algunos de estos servicios:

| Servicio | Para qué sirve |
|----------|----------------|
| **WordPress** | Tu web corporativa, gestionable tú mismo/a. |
| **Nextcloud** | Tu almacenamiento y carpetas compartidas en la nube privada. |
| **Vaultwarden** | Gestor de contraseñas de la empresa (compatible con Bitwarden). |
| **Gitea** | Repositorios de código autogestionados. |
| **PrestaShop** | Tu tienda online. |
| **VPN (WireGuard)** | Acceso remoto seguro a la red de la empresa. |
| **Jitsi** | Videollamadas corporativas. |
| **Uptime Kuma / Grafana** | Estado y métricas de tus servicios. |

Cada servicio tiene, además, su propia ayuda interna una vez dentro.

---

## 6. Preguntas frecuentes

**He olvidado mi contraseña.**
Contacta con el soporte (ver sección 7) para que la restablezca. Por seguridad, no puede recuperarse en texto plano.

**He perdido el móvil con la app de autenticación.**
Avisa al soporte cuanto antes. Se te ayudará a reconfigurar el segundo factor con un dispositivo nuevo.

**Al abrir un servicio me sale «403 Forbidden».**
Significa que tu usuario no tiene permiso para ese servicio. Normalmente ocurre si intentas abrir un servicio que no es de tu empresa. Si crees que es un error, contacta con soporte indicando qué servicio intentabas abrir.

**Me pide iniciar sesión una y otra vez.**
Tu sesión ha caducado por inactividad. Vuelve a iniciar sesión; si el problema persiste, prueba a borrar las cookies del navegador o usa una ventana nueva.

**Un servicio no carga o da error.**
Espera unos minutos y reinténtalo. Si sigue sin funcionar, contacta con soporte indicando el nombre del servicio y la hora aproximada.

**¿Mis datos están seguros?**
Sí. Cada empresa opera en un entorno **aislado** del resto, con sus propias credenciales. La conexión va siempre cifrada (HTTPS) y el acceso está protegido con doble factor. Los datos se alojan en servidores en España.

---

## 7. Soporte

Si tienes cualquier incidencia o duda:

- **Correo:** soporte@tensaas.es
- **Horario y canal** según tu plan contratado (correo o chat).

Al contactar, indica:
- el **nombre de tu empresa** y tu **usuario**,
- el **servicio** afectado,
- una **descripción** del problema y, si es posible, la **hora** en que ocurrió.

Cuanta más información facilites, antes podremos ayudarte.
