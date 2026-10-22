#!/bin/sh
set -e

MYSQL_USER_PASSWORD=$(cat /run/secrets/db_password)
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

check() {
    if [ -z "$2" ]; then
        echo "Error : var $1 is empty" >&2
        exit 1
    fi
}

check MYSQL_DATABASE      "$MYSQL_DATABASE"
check MYSQL_USER          "$MYSQL_USER"
check MYSQL_USER_PASSWORD "$MYSQL_USER_PASSWORD"
check MYSQL_ROOT_PASSWORD "$MYSQL_ROOT_PASSWORD"

if [ ! -d /var/lib/mysql/mysql ]; then
    chown -R mysql:mysql /var/lib/mysql
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
fi

if [ ! -d "/var/lib/mysql/$MYSQL_DATABASE" ]; then
    mariadbd --user=mysql --bootstrap <<EOF
USE mysql;
FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE;
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_USER_PASSWORD';
GRANT ALL PRIVILEGES ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';
FLUSH PRIVILEGES;
EOF
fi

exec mariadbd --user=mysql