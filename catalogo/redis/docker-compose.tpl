services:
  redis:
    container_name: {{EMPRESA}}_redis
    image: redis:7.2.3
    restart: always
    command: ["redis-server", "--requirepass", "{{REDIS_PASSWORD}}"]
    volumes:
      - {{RUTA_DATOS}}/redis:/data
    networks:
      - {{EMPRESA}}_net
    ports:
      - "{{PUERTO}}:6379"

networks:
  {{EMPRESA}}_net:
    external: true
