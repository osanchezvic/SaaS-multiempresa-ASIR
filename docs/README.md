# IaaS-multiempresa-ASIR
Proyecto Final ASIR: Plataforma IaaS multiempresa con despliegue automático de servicios mediante Docker, Bashy y Nginx Proxy Manager".

## Descripción General
Este proyecto consiste en la creación de una plataforma IaaS capaz de ofrecer servicios a múltiples empresas desde un único servidor.
Cada empresa tendrá sus propios servicios aislados mediante Docker, redes independientes y dominios personalizados.

El objetivo principal es automatizar completamente el despliegue de servicios mediante scripts en BASH, integrando herramientas como Docker, Nginx Proxy Manager y Dashy.

Este proyecto forma parte del Trabajo de Fin de Ciclo de ASIR.

---

## Objetivos del proyecto

- Crear una infraestructura multiempresa (multi-tenant) aislada y segura.
- Automatizar el despliegue de servicios mediante scripts BASH.
- Gestionar contenedores Docker de forma modular y reproducible.
- Integrar un proxy inverso (Nginx Proxy Manager) para gestionar dominios y certificados SSL.
- Proporcionar un panel de acceso para clientes mediante Dashy.
- Facilitar la administración mediante un panel interno y registro de servicios.
- Implementar monitorización básica (Prometheus, Grafana).

  ---

## Arquitectura prevista
- **Servidor Base**: Ubuntu Server LTS
- **Contenedores**: Docker + Docker Compose
- **Proxy Inverso**: Nginx Proxy Manager
- **Panel del Cliente**: Dashy
- **Automatización**: Scripts BASH
- **Monitorización**: Prometheus + Grafana
  
**ESTRUCTURA POR EMPRESA**
-   Redes Docker independientes
-   Volúmenes separados
-   Subdominios por servicio

---

## Licencia
Este proyecto está bajo licencia **MIT**, lo que permite su uso, copia y modificación con atribución.

---

## Autor
**Óscar Sánchez Victoria**
*osanchezvic@gmail.com*
