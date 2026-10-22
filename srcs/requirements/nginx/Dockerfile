
FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y nginx openssl \
    && rm -rf /var/lib/apt/lists/* \
    && rm /etc/nginx/sites-enabled/default \
    && rm -rf /var/www/html/* \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

COPY conf/inception.conf /etc/nginx/conf.d/

COPY --chmod=755 tools/nginx-setup.sh /usr/local/bin/

EXPOSE 443

CMD ["/usr/local/bin/nginx-setup.sh"]