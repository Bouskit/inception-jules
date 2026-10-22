
FROM debian:bookworm 

RUN apt-get update \
    && apt-get install -y \
    curl \
    php-fpm \
    php-mysql \
    php-gd \
    php-curl \
    php-xml \
    php-mbstring \
    php-zip \
    php-intl \
    php-redis \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/

COPY --chmod=755 tools/wp-setup.sh /usr/local/bin/

EXPOSE 9000

CMD ["/usr/local/bin/wp-setup.sh"]