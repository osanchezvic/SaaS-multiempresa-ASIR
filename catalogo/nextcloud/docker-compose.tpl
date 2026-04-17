services:
  nextcloud:
    container_name: {{EMPRESA}}_nextcloud
    image: nextcloud:28.0.0
    restart: always
    environment:
      - MYSQL_HOST={{EMPRESA}}_mariadb
      - MYSQL_DATABASE={{DB_NAME}}
      - MYSQL_USER={{DB_USER}}
      - MYSQL_PASSWORD={{DB_PASSWORD}}
    volumes:
      - {{RUTA_DATOS}}/nextcloud:/var/www/html
    networks:
      - {{EMPRESA}}_net
    ports:
      - "{{PUERTO}}:80"

networks:
  {{EMPRESA}}_net:
    external: true
