services:
  {{EMPRESA}}_jitsi_web:
    image: jitsi/web:latest
    container_name: {{EMPRESA}}_jitsi_web
    restart: always
    ports:
      - "{{PUERTO}}:80"
    environment:
      - PUBLIC_URL=http://localhost:{{PUERTO}}
      - XMPP_DOMAIN=meet.jitsi
      - XMPP_AUTH_DOMAIN=auth.meet.jitsi
      - XMPP_BOSH_URL_BASE=http://{{EMPRESA}}_jitsi_prosody:5280
      - XMPP_GUEST_DOMAIN=guest.meet.jitsi
      - XMPP_MUC_DOMAIN=muc.meet.jitsi
      - JICOFO_COMPONENT_SECRET={{JWT_SECRET}}
      - JICOFO_AUTH_USER=focus
      - JVB_AUTH_USER=jvb
    networks:
      - {{EMPRESA}}_net
    depends_on:
      - {{EMPRESA}}_jitsi_prosody

  {{EMPRESA}}_jitsi_prosody:
    image: jitsi/prosody:latest
    container_name: {{EMPRESA}}_jitsi_prosody
    restart: always
    environment:
      - XMPP_DOMAIN=meet.jitsi
      - XMPP_AUTH_DOMAIN=auth.meet.jitsi
      - XMPP_GUEST_DOMAIN=guest.meet.jitsi
      - XMPP_MUC_DOMAIN=muc.meet.jitsi
      - JICOFO_COMPONENT_SECRET={{JWT_SECRET}}
      - JICOFO_AUTH_USER=focus
      - JVB_AUTH_USER=jvb
      - JVB_AUTH_PASSWORD={{DB_PASSWORD}}
      - JICOFO_AUTH_PASSWORD={{DB_PASSWORD}}
    networks:
      - {{EMPRESA}}_net

  {{EMPRESA}}_jitsi_jicofo:
    image: jitsi/jicofo:latest
    container_name: {{EMPRESA}}_jitsi_jicofo
    restart: always
    environment:
      - XMPP_DOMAIN=meet.jitsi
      - XMPP_AUTH_DOMAIN=auth.meet.jitsi
      - XMPP_SERVER={{EMPRESA}}_jitsi_prosody
      - JICOFO_COMPONENT_SECRET={{JWT_SECRET}}
      - JICOFO_AUTH_USER=focus
      - JICOFO_AUTH_PASSWORD={{DB_PASSWORD}}
    networks:
      - {{EMPRESA}}_net
    depends_on:
      - {{EMPRESA}}_jitsi_prosody

  {{EMPRESA}}_jitsi_jvb:
    image: jitsi/jvb:latest
    container_name: {{EMPRESA}}_jitsi_jvb
    restart: always
    environment:
      - XMPP_DOMAIN=meet.jitsi
      - XMPP_AUTH_DOMAIN=auth.meet.jitsi
      - XMPP_SERVER={{EMPRESA}}_jitsi_prosody
      - JVB_AUTH_USER=jvb
      - JVB_AUTH_PASSWORD={{DB_PASSWORD}}
      - JVB_STUN_SERVERS=stun.l.google.com:19302,stun1.l.google.com:19302
    networks:
      - {{EMPRESA}}_net
    depends_on:
      - {{EMPRESA}}_jitsi_prosody

networks:
  {{EMPRESA}}_net:
    external: true
