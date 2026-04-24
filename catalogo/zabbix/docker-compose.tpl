services:
  zabbix:
    container_name: {{EMPRESA}}_zabbix
    image: zabbix/zabbix-appliance:latest
    restart: always
    environment:
      - ZBX_SERVER_NAME={{EMPRESA}}_zabbix
      - PHP_TZ=Europe/Madrid
    volumes:
      - {{RUTA_DATOS}}/zabbix:/var/lib/zabbix
    networks:
      - {{EMPRESA}}_net
    ports:
      - "{{PUERTO}}:80"   # Frontend web
      # - "10051:10051"     # Puerto del servidor Zabbix (Desactivado para evitar conflictos)

networks:
  {{EMPRESA}}_net:
    external: true
