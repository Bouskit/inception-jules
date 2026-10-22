#!/bin/sh
set -e

# 1. Read the secrets
MYSQL_USER_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

# 2. Check the variables
check() {
    if [ -z "$2" ]; then
        echo "Error : $1 variable is empty" >&2
        exit 1
    fi
}

check MYSQL_DATABASE        "$MYSQL_DATABASE"
check MYSQL_USER            "$MYSQL_USER"
check MYSQL_USER_PASSWORD   "$MYSQL_USER_PASSWORD"
check DOMAIN_NAME           "$DOMAIN_NAME"
check WP_TITLE              "$WP_TITLE"
check WP_ADMIN_USER         "$WP_ADMIN_USER"
check WP_ADMIN_PASSWORD     "$WP_ADMIN_PASSWORD"
check WP_ADMIN_EMAIL        "$WP_ADMIN_EMAIL"
check WP_USER               "$WP_USER"
check WP_USER_PASSWORD      "$WP_USER_PASSWORD"
check WP_USER_EMAIL         "$WP_USER_EMAIL"

# Subject rule: no "admin" in the administrator name
case "$(echo "$WP_ADMIN_USER" | tr 'A-Z' 'a-z')" in
    *admin*)
        echo "Error : must not have 'admin' in admin name" >&2
        exit 1
        ;;
esac

mkdir -p /var/www/html
cd /var/www/html

# 3. Wait for MariaDB (every start: the Redis block below also needs the database)
tries=0
until mariadb-admin ping -h mariadb -u "$MYSQL_USER" -p"$MYSQL_USER_PASSWORD" --silent; do
    tries=$((tries + 1))
    if [ "$tries" -ge 30 ]; then
        echo "Error : MariaDB not responding" >&2
        exit 1
    fi
    sleep 1
done

# 4. First start only: install WordPress
if [ ! -f wp-config.php ]; then

    wp core download --allow-root

    wp config create --allow-root \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$MYSQL_USER_PASSWORD" \
        --dbhost=mariadb:3306

    wp core install --allow-root \
        --url="https://$DOMAIN_NAME" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email

    wp user create "$WP_USER" "$WP_USER_EMAIL" --allow-root \
        --role=author \
        --user_pass="$WP_USER_PASSWORD"

    chown -R www-data:www-data /var/www/html
fi

# 5. Redis cache (bonus): enabled only when the redis container exists
if getent hosts redis > /dev/null; then
    if ! wp plugin is-installed redis-cache --allow-root; then
        wp plugin install redis-cache --allow-root
        chown -R www-data:www-data wp-content/plugins/redis-cache
    fi
    wp config set WP_REDIS_HOST redis --allow-root
    wp config set WP_REDIS_PORT 6379 --raw --allow-root
    wp plugin activate redis-cache --allow-root
    if [ ! -f wp-content/object-cache.php ]; then
        wp redis enable --allow-root
    fi
else
    rm -f wp-content/object-cache.php
    if wp plugin is-active redis-cache --allow-root; then
        wp plugin deactivate redis-cache --allow-root
    fi
fi

# 6. Replace the shell with php-fpm, in the foreground, as PID 1
exec php-fpm8.2 -F

