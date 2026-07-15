#!/bin/sh

set -e

echo "Starting WordPress..."

mkdir -p /run/php

cd /var/www/html

echo "Waiting for MariaDB..."

until mysqladmin ping \
    -h"$MYSQL_HOST" \
    -u"$MYSQL_USER" \
    -p"$MYSQL_PASSWORD" \
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
        --dbpass="$MYSQL_PASSWORD" \
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
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --allow-root

    echo "Creating normal user..."

    wp user create \
        "$WP_USER" \
        "$WP_USER_EMAIL" \
        --user_pass="$WP_USER_PASSWORD" \
        --role=author \
        --allow-root
fi

// add exentation for redis cache

echo "Starting PHP-FPM..."

exec /usr/sbin/php-fpm8.2 -F