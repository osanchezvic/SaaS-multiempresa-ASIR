services:
  {{EMPRESA}}_wordpress:
    image: wordpress:6.4.2
    container_name: {{EMPRESA}}_wordpress
    restart: always
    depends_on:
      - mariadb
    environment:
      WORDPRESS_DB_HOST: {{EMPRESA}}_mariadb
      WORDPRESS_DB_USER: {{DB_USER}}
      WORDPRESS_DB_PASSWORD: {{DB_PASSWORD}}
      WORDPRESS_DB_NAME: {{DB_NAME}}
    ports:
      - "{{PUERTO}}:80"
    volumes:
      - {{RUTA_DATOS}}/wordpress:/var/www/html
    networks:
      - {{EMPRESA}}_net

networks:
  {{EMPRESA}}_net:
    external: true
