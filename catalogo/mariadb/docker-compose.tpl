services:
  mariadb:
    container_name: {{EMPRESA}}_mariadb
    image: mariadb:latest
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD={{DB_ROOT_PASSWORD}}
      - MYSQL_DATABASE={{DB_NAME}}
      - MYSQL_USER={{DB_USER}}
      - MYSQL_PASSWORD={{DB_PASSWORD}}
    volumes:
      - {{RUTA_DATOS}}/mariadb:/var/lib/mysql
    networks:
      - {{EMPRESA}}_net
    # Sin publicar puerto al host: la BD es interna y solo se accede por la
    # red de la empresa ({{EMPRESA}}_net) vía DNS de contenedor
    # ({{EMPRESA}}_mariadb:3306). Publicarla colisionaba entre tenants
    # (todos pedían el mismo puerto) y rompía el modelo zero-exposure.

networks:
  {{EMPRESA}}_net:
    external: true
