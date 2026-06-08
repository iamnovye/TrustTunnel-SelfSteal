#!/bin/sh
set -e

PANEL_PATH="${PANEL_PATH:-manage}"
DOMAIN="${DOMAIN:-_}"
USE_HTTPS="${USE_HTTPS:-false}"

if [ "$USE_HTTPS" = "true" ]; then
    TMPL=/etc/nginx/templates/nginx.ssl.conf.template
else
    TMPL=/etc/nginx/templates/nginx.conf.template
fi

export PANEL_PATH DOMAIN
envsubst '${PANEL_PATH} ${DOMAIN}' < "$TMPL" > /etc/nginx/conf.d/default.conf

exec nginx -g "daemon off;"
