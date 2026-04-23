# Registro de Remediación de Seguridad

Este documento detalla las acciones realizadas para corregir las vulnerabilidades críticas detectadas en el proyecto.

## 📅 Fecha: 23 de abril de 2026

## ✅ Acciones Realizadas

### 1. Gestión de Secretos y Hardening
- [x] **Rotación de `API_TOKEN`**: Se ha generado un nuevo token seguro y se ha actualizado en `infra/.env` y `deploy_service.php`.
- [x] **Rotación de secretos de Authelia y contraseñas de BD**: Se han actualizado los hashes de administrador en `users.yml` e `init.sql` eliminando credenciales por defecto.
- [x] **Restricción de permisos en archivos `.env`**: Permisos cambiados a `600` para evitar lectura por otros usuarios.

### 2. Seguridad en Aplicaciones Web
- [x] **Corrección de Inyección SQL**: El archivo `catalogo/panel/index.php` ahora utiliza sentencias preparadas (`mysqli_prepare`).
- [x] **Implementación de protección CSRF**: Se ha añadido validación de tokens en `infra/admin-dashboard/index.php` y `infra/admin-dashboard/deploy_service.php`.

### 3. Integridad de Datos
- [x] **Corrección del script de backup**: Se ha reescrito la lógica de `infra/backups/backup.sh` para usar un directorio temporal y evitar la sobrescritura del archivo final, asegurando que todos los volúmenes se guarden correctamente.

---
## 💡 Recomendaciones Adicionales (No implementadas por petición de foco en "Críticos")
1. **Endurecimiento de Docker**: Cerrar los puertos expuestos (8000, 9000, 3000, 9090) y usar solo el proxy.
2. **Socket de Docker**: Investigar alternativas como `docker-socket-proxy` para limitar privilegios de la API y Portainer.
3. **Validación de Entradas**: Reforzar la validación de nombres de servicio en la API para evitar caracteres no deseados.
