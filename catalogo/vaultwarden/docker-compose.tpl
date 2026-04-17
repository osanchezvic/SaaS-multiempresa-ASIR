services:
  vaultwarden:
    container_name: {{EMPRESA}}_vaultwarden
    image: vaultwarden/server:1.30.0
    restart: always
    environment:
      - ADMIN_TOKEN={{ADMIN_TOKEN}}
      - DOMAIN={{DOMAIN}}
      - SIGNUPS_ALLOWED=false
      - WEBSOCKET_ENABLED=true
    volumes:
      - {{RUTA_DATOS}}/vaultwarden:/data
    networks:
      - {{EMPRESA}}_net
    ports:
      - "{{PUERTO}}:80"

networks:
  {{EMPRESA}}_net:
    external: true
