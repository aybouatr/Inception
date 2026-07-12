#!/bin/sh
set -e

echo "Starting WordPress container..."

cd /var/www/html

mkdir -p /run/php

# If WordPress is not downloaded, download it
if [ ! -f wp-load.php ]; then
    echo "Downloading WordPress..."
    php -d memory_limit=512M /usr/local/bin/wp core download --allow-root
fi

echo "WordPress ready. Starting PHP-FPM..."
exec php-fpm -F
