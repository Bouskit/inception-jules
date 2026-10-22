
FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y vsftpd \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/vsftpd/empty

COPY conf/vsftpd.conf /etc/vsftpd.conf

COPY --chmod=755 tools/ftp-setup.sh /usr/local/bin/

EXPOSE 21 21100-21110

CMD ["/usr/local/bin/ftp-setup.sh"]