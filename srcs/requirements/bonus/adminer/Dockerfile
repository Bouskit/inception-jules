
FROM debian:bookworm

ARG ADMINER_VERSION=6.0.1

RUN apt-get update \
    && apt-get install -y curl php-cli php-mysql \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/adminer \
    && curl -fL -o /var/www/adminer/index.php \
    https://github.com/vrana/adminer/releases/download/v${ADMINER_VERSION}/adminer-${ADMINER_VERSION}-mysql.php

EXPOSE 8080

USER www-data

CMD ["php", "-S", "0.0.0.0:8080", "-t", "/var/www/adminer"]