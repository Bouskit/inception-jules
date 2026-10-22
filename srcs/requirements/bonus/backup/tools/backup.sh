#!/bin/sh
set -e

# Values saved by backup-setup.sh (cron does not pass the container environment)
. /etc/backup.env
DB_PASSWORD=$(cat /run/secrets/db_password)

DATE=$(date +%Y-%m-%d_%H-%M-%S)
DEST="/backups/$DATE"
KEEP=7

echo "[$DATE] Backup started"
mkdir -p "$DEST"

# 1. Database: a full SQL export, then compressed
mariadb-dump -h mariadb -u "$MYSQL_USER" -p"$DB_PASSWORD" \
    --single-transaction --no-tablespaces "$MYSQL_DATABASE" > "$DEST/database.sql"
gzip "$DEST/database.sql"

# 2. WordPress files: a compressed archive of the volume
tar -czf "$DEST/wordpress.tar.gz" -C /var/www/html .

# 3. Keep only the most recent backups
ls -1d /backups/*/ | sort | head -n -"$KEEP" | xargs -r rm -rf

echo "[$DATE] Backup done: $(du -sh "$DEST" | cut -f1)"