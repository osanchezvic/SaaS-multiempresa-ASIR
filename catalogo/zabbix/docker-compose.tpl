services:
  zabbix:
    container_name: {{EMPRESA}}_zabbix
    image: zabbix/zabbix-appliance:6.4.9
    restart: always
    environment:
      - ZBX_SERVER_NAME={{EMPRESA}}_zabbix
      - PHP_TZ=Europe/Madrid
    volumes:
      - {{RUTA_DATOS}}/zabbix:/var/lib/zabbix
    networks:
      - {{EMPRESA}}_net
    ports:
      - "{{PUERTO}}:8080"   # Frontend web
      - "{{PUERTO2}}:10051" # Puerto del servidor Zabbix

networks:
  {{EMPRESA}}_net:
    external: true
