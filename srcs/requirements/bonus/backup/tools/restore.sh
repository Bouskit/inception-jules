#!/bin/sh
set -e

. /etc/backup.env
DB_PASSWORD=$(cat /run/secrets/db_password)

if [ -z "$1" ] || [ ! -f "/backups/$1/database.sql.gz" ]; then
    echo "Usage: restore.sh <backup-name>" >&2
    echo "Available backups:" >&2
    ls -1 /backups >&2
    exit 1
fi

echo "Restoring the database from backup $1..."
gunzip -c "/backups/$1/database.sql.gz" \
    | mariadb -h mariadb -u "$MYSQL_USER" -p"$DB_PASSWORD" "$MYSQL_DATABASE"
echo "Database restored."