services:
  node_exporter:
    container_name: {{EMPRESA}}_node_exporter
    image: prom/node-exporter:v1.6.1
    restart: always
    command:
      - '--path.rootfs=/host'
    pid: host
    volumes:
      - /:/host:ro,rslave
    networks:
      - {{EMPRESA}}_net
    ports:
      - "{{PUERTO}}:9100"

networks:
  {{EMPRESA}}_net:
    external: true
