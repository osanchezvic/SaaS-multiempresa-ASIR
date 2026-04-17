services:
  nginx:
    container_name: {{EMPRESA}}_nginx
    image: nginx:1.25.3
    restart: always
    volumes:
      - {{RUTA_DATOS}}/nginx/html:/usr/share/nginx/html:ro
      - {{RUTA_DATOS}}/nginx/conf.d:/etc/nginx/conf.d
    networks:
      - {{EMPRESA}}_net
    ports:
      - "{{PUERTO}}:80"

networks:
  {{EMPRESA}}_net:
    external: true
