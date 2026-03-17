services:
  redis:
    container_name: {{EMPRESA}}_redis
    image: redis:latest
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
