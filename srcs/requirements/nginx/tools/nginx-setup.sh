#!/bin/sh
set -e

if [ -z "$DOMAIN_NAME" ]; then
    echo "Error: var DOMAIN_NAME is empty" >&2
    exit 1
fi

mkdir -p /etc/nginx/ssl
if [ ! -f /etc/nginx/ssl/cert.pem ]; then
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout /etc/nginx/ssl/key.pem \
        -out /etc/nginx/ssl/cert.pem \
        -subj "/CN=$DOMAIN_NAME"
fi

exec nginx -g "daemon off;"