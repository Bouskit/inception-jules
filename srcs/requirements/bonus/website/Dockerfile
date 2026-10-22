
FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y nginx \
    && rm -rf /var/lib/apt/lists/* \
    && rm /etc/nginx/sites-enabled/default \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

COPY conf/website.conf /etc/nginx/conf.d

COPY site/ /var/www/website

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]