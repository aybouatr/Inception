#!/bin/sh

set -e

echo "Starting WordPress..."

mkdir -p /run/php

cd /var/www/html

echo "Waiting for MariaDB..."

until mysqladmin ping \
    -h"$MYSQL_HOST" \
    -u"$MYSQL_USER" \
    -p"$(cat /run/secrets/mysql_user_password)" \
    --silent
do
    sleep 2
done

echo "MariaDB is ready."

if [ ! -f wp-load.php ]; then
    echo "Downloading WordPress..."

    wp core download \
        --allow-root
fi

if [ ! -f wp-config.php ]; then
    echo "Creating wp-config.php..."

    wp config create \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$(cat /run/secrets/mysql_user_password)" \
        --dbhost="$MYSQL_HOST" \
        --allow-root
fi


if ! wp core is-installed --allow-root
then
    echo "Installing WordPress..."

    wp core install \
        --url="$DOMAIN_NAME" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$(cat /run/secrets/wp_admin_password)" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --allow-root

    echo "Creating normal user..."

    wp user create \
        "$WP_USER" \
        "$WP_USER_EMAIL" \
        --user_pass="$(cat /run/secrets/wp_user_password)" \
        --role=author \
        --allow-root
fi

# Add extension for Redis cache

echo "Configuring Redis..."

wp plugin install redis-cache --activate --allow-root || true

wp config set WP_REDIS_HOST redis --allow-root || true
wp config set WP_REDIS_PORT 6379 --allow-root || true
wp config set WP_CACHE true --raw --allow-root || true

wp redis enable --allow-root || true

echo "Redis cache configured!"

echo "Starting PHP-FPM..."

exec /usr/sbin/php-fpm8.2 -F