
FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y cron mariadb-client \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=644 conf/backup.cron /etc/cron.d/backup

COPY --chmod=755 tools/backup-setup.sh tools/backup.sh tools/restore.sh /usr/local/bin/

CMD ["/usr/local/bin/backup-setup.sh"]