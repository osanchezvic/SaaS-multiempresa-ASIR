services:
  phpmyadmin:
    container_name: {{EMPRESA}}_phpmyadmin
    image: phpmyadmin/phpmyadmin:5.2.1
    restart: always
    environment:
      - PMA_HOST={{EMPRESA}}_mariadb
      - PMA_USER={{DB_USER}}
      - PMA_PASSWORD={{DB_PASSWORD}}
      - UPLOAD_LIMIT=512M
    networks:
      - {{EMPRESA}}_net
    ports:
      - "{{PUERTO}}:80"

networks:
  {{EMPRESA}}_net:
    external: true
