services:
  {{EMPRESA}}_gitea:
    image: gitea/gitea:1.21
    container_name: {{EMPRESA}}_gitea
    restart: always
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=mysql
      - GITEA__database__HOST={{EMPRESA}}_mariadb:3306
      - GITEA__database__NAME={{DB_NAME}}
      - GITEA__database__USER={{DB_USER}}
      - GITEA__database__PASSWD={{DB_PASSWORD}}
      - APP_NAME={{EMPRESA}} Git Service
      - RUN_MODE=prod
      - DOMAIN=localhost
      - SSH_DOMAIN=localhost
      - HTTP_PORT=3000
      - ROOT_URL=http://localhost:{{PUERTO}}
      - SSH_PORT=2222
    ports:
      - "{{PUERTO}}:3000"
      - "2222:22"
    volumes:
      - {{RUTA_DATOS}}/gitea:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    networks:
      - {{EMPRESA}}_net

networks:
  {{EMPRESA}}_net:
    external: true
