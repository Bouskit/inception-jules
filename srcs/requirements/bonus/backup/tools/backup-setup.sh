#!/bin/sh
set -e

# 1. Check the variables and the secret
check() {
    if [ -z "$2" ]; then
        echo "Error : $1 variable is empty" >&2
        exit 1
    fi
}

check MYSQL_DATABASE "$MYSQL_DATABASE"
check MYSQL_USER     "$MYSQL_USER"
check db_password    "$(cat /run/secrets/db_password)"

# 2. cron jobs start with an almost empty environment:
#    save the values the backup job needs in a file it will read
cat > /etc/backup.env <<EOF
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_USER=$MYSQL_USER
EOF
chmod 600 /etc/backup.env

# 3. Backups contain the whole database: only root may read them
mkdir -p /backups
chmod 700 /backups

# 4. Replace the shell with cron, in the foreground, as PID 1
exec cron -f