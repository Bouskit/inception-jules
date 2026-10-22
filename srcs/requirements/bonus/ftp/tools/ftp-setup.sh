#!/bin/sh
set -e

# 1. Read the secret
FTP_PASSWORD=$(cat /run/secrets/ftp_password)

# 2. Check the variables
check() {
    if [ -z "$2" ]; then
        echo "Error : $1 variable is empty" >&2
        exit 1
    fi
}

check FTP_USER     "$FTP_USER"
check FTP_PASSWORD "$FTP_PASSWORD"

# 3. Create the FTP user once, sharing UID/GID 33 with www-data
if ! id "$FTP_USER" > /dev/null 2>&1; then
    useradd --non-unique --uid 33 --gid 33 \
        --home-dir /var/www/html --no-create-home \
        --shell /bin/bash "$FTP_USER"
fi

# 4. Set the password (every start, in case the secret changed)
echo "$FTP_USER:$FTP_PASSWORD" | chpasswd

# 5. Replace the shell with vsftpd, in the foreground, as PID 1
exec vsftpd /etc/vsftpd.conf