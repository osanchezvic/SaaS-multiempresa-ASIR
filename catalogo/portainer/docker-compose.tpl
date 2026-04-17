services:
  portainer:
    container_name: {{EMPRESA}}_portainer
    image: portainer/portainer-ce:2.19.4
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - {{RUTA_DATOS}}/portainer/data:/data
    networks:
      - {{EMPRESA}}_net
    ports:
      - "{{PUERTO}}:9000"

networks:
  {{EMPRESA}}_net:
    external: true
