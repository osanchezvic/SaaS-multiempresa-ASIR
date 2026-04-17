services:
  wireguard:
    container_name: {{EMPRESA}}_wireguard
    image: linuxserver/wireguard:1.0.20231011
    restart: always
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Madrid
      - SERVERURL={{DOMAIN}}
      - SERVERPORT={{PUERTO}}
      - PEERS={{PEERS}}
      - PEERDNS=1.1.1.1
      - INTERNAL_SUBNET={{SUBNET}}
    volumes:
      - {{RUTA_DATOS}}/wireguard/config:/config
      - /lib/modules:/lib/modules
    ports:
      - "{{PUERTO}}:51820/udp"
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    networks:
      - {{EMPRESA}}_net

networks:
  {{EMPRESA}}_net:
    external: true
