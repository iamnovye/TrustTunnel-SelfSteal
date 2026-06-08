#!/bin/sh
set -e

PANEL_PATH="${PANEL_PATH:-manage}"
export PANEL_PATH

envsubst '${PANEL_PATH}' \
    < /etc/nginx/templates/nginx.conf.template \
    > /etc/nginx/conf.d/default.conf

exec nginx -g "daemon off;"
