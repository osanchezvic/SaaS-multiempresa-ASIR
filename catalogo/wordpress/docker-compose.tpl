services:
  wordpress:
    container_name: {{EMPRESA}}_wordpress
    image: wordpress:latest
    restart: always
    environment:
      - WORDPRESS_DB_HOST={{EMPRESA}}_mariadb
      - WORDPRESS_DB_NAME={{DB_NAME}}
      - WORDPRESS_DB_USER={{DB_USER}}
      - WORDPRESS_DB_PASSWORD={{DB_PASSWORD}}
    volumes:
      - {{RUTA_DATOS}}/wordpress:/var/www/html
    networks:
      - {{EMPRESA}}_net
    ports:
      - "{{PUERTO}}:80"

networks:
  {{EMPRESA}}_net:
    external: true
