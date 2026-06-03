#!/bin/bash
# Actualiza el advanced_config de los proxy hosts EXISTENTES en NPM para quitar
# "satisfy any; allow 127.0.0.1;" (que convertía el 401 de Authelia en 403 e
# impedía el redirect al login). Deja el bloque idéntico al que genera el
# npm.sh ya corregido. Es DURABLE: escribe en la BD de NPM, no en el .conf
# horneado (que NPM regenera).
#
# Uso:  bash scripts/fix_authelia_existing_hosts.sh
set -euo pipefail

cd "$(dirname "$0")"
source ./config.env
NPM_URL="${NPM_URL:-http://localhost:81}"

# Bloque canónico (igual que npm_add_proxy en funciones/npm.sh, sin satisfy/allow
# y con redirect via named location @error401 para no disparar block-exploits)
read -r -d '' ADV <<'EOF' || true
auth_request /authelia;
auth_request_set $user $upstream_http_remote_user;
auth_request_set $groups $upstream_http_remote_groups;
proxy_set_header Remote-User $user;
proxy_set_header Remote-Groups $groups;
error_page 401 = @error401;
EOF

echo ">> Obteniendo token NPM..."
TOKEN=$(curl -s -X POST "${NPM_URL}/api/tokens" \
    -H "Content-Type: application/json" \
    -d "{\"identity\": \"${NPM_USER}\", \"secret\": \"${NPM_PASSWORD}\"}" \
    | jq -r .token)
[ -n "$TOKEN" ] && [ "$TOKEN" != "null" ] || { echo "ERROR: token NPM vacío"; exit 1; }

for ID in 20 22 9 21 17; do
    echo ">> Host $ID ..."
    OBJ=$(curl -s -X GET "${NPM_URL}/api/nginx/proxy-hosts/${ID}" \
        -H "Authorization: Bearer ${TOKEN}")
    DOMAIN=$(echo "$OBJ" | jq -r '.domain_names[0]')

    # Reconstruir el payload editable manteniendo todos los campos relevantes
    PAYLOAD=$(echo "$OBJ" | jq --arg adv "$ADV" '{
        domain_names, forward_scheme, forward_host, forward_port,
        certificate_id, ssl_forced, hsts_enabled, hsts_subdomains,
        http2_support, block_exploits, caching_enabled,
        allow_websocket_upgrade, access_list_id, enabled,
        locations: (.locations // []),
        advanced_config: $adv
    }')

    RESP=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
        "${NPM_URL}/api/nginx/proxy-hosts/${ID}" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")
    echo "   $DOMAIN -> HTTP $RESP"
done

echo ">> Validando nginx..."
docker exec nginx_proxy_manager nginx -t

echo ">> Reiniciando Authelia (recarga configuration.yml con domain_regex)..."
docker restart authelia >/dev/null
echo ">> Hecho."
