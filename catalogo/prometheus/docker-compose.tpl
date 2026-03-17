services:
  prometheus:
    container_name: {{EMPRESA}}_prometheus
    image: prom/prometheus:latest
    restart: always
    volumes:
      - {{RUTA_DATOS}}/prometheus:/prometheus
      - {{RUTA_DATOS}}/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'
    networks:
      - {{EMPRESA}}_net
    ports:
      - "{{PUERTO}}:9090"

networks:
  {{EMPRESA}}_net:
    external: true
