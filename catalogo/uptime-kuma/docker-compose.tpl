services:
  uptime-kuma:
    container_name: {{EMPRESA}}_uptime_kuma
    image: louislam/uptime-kuma:latest
    restart: always
    volumes:
      - {{RUTA_DATOS}}/uptime-kuma:/app/data
    networks:
      - {{EMPRESA}}_net
    ports:
      - "{{PUERTO}}:3001"

networks:
  {{EMPRESA}}_net:
    external: true
