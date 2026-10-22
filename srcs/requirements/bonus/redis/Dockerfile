
FROM debian:bookworm

RUN apt-get update \ 
    && apt-get install -y redis-server \
    && rm -rf /var/lib/apt/lists/*

COPY conf/redis.conf /etc/redis/inception.conf

EXPOSE 6379

USER redis

CMD ["redis-server", "/etc/redis/inception.conf"]