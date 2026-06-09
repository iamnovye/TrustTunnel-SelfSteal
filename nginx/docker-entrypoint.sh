#!/bin/sh
set -e

PANEL_PATH="${PANEL_PATH:-manage}"
export PANEL_PATH

# Build optional HTTPS server block if cert and key are present
SSL_CERT="${SSL_CERT:-}"
SSL_KEY="${SSL_KEY:-}"

if [ -n "$SSL_CERT" ] && [ -f "$SSL_CERT" ] && [ -n "$SSL_KEY" ] && [ -f "$SSL_KEY" ]; then
    NGINX_SSL_SERVER="server {
    listen 8443 ssl;
    server_name _;
    ssl_certificate     ${SSL_CERT};
    ssl_certificate_key ${SSL_KEY};
    ssl_protocols       TLSv1.2 TLSv1.3;
    root /usr/share/nginx/decoy;
    index index.html;
    location /${PANEL_PATH}/ {
        alias /usr/share/nginx/panel/;
        try_files \$uri \$uri/ /${PANEL_PATH}/index.html;
    }
    location /${PANEL_PATH}/api/ {
        rewrite ^/${PANEL_PATH}/api/(.*) /api/\$1 break;
        proxy_pass http://backend:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 30s;
    }
    location / {
        try_files \$uri \$uri/ /index.html;
    }
}"
    export NGINX_SSL_SERVER
else
    NGINX_SSL_SERVER=""
    export NGINX_SSL_SERVER
fi

envsubst '${PANEL_PATH} ${NGINX_SSL_SERVER}' \
    < /etc/nginx/templates/nginx.conf.template \
    > /etc/nginx/conf.d/default.conf

exec nginx -g "daemon off;"
