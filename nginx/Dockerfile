FROM nginx:1.27-alpine

RUN apk add --no-cache gettext

# Config templates
COPY nginx.conf      /etc/nginx/templates/nginx.conf.template
COPY nginx.ssl.conf  /etc/nginx/templates/nginx.ssl.conf.template

# Startup script: pick HTTP or HTTPS config, substitute vars, launch nginx
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
