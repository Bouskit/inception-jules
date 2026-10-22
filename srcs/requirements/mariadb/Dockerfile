
FROM debian:bookworm

RUN apt-get update && apt-get install -y mariadb-server && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld

COPY conf/51-mdb.cnf /etc/mysql/mariadb.conf.d/

COPY --chmod=755 tools/mdb-setup.sh /usr/local/bin/

EXPOSE 3306

CMD ["/usr/local/bin/mdb-setup.sh"]