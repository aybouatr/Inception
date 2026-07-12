FROM php:8.2-fpm-alpine

WORKDIR /var/www/html

# Install packages and PHP extensions
RUN apk add --no-cache \
    mariadb-client \
    curl \
    bash \
    && docker-php-ext-install mysqli pdo pdo_mysql

RUN echo "memory_limit = 512M" > /usr/local/etc/php/conf.d/memory-limit.ini

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Copy PHP-FPM configuration
COPY config/www.conf /usr/local/etc/php-fpm.d/www.conf

# Copy startup script
COPY tools/wp_setup.sh /usr/local/bin/wp_setup.sh

RUN chmod +x /usr/local/bin/wp_setup.sh

RUN mkdir -p /run/php \
    && mkdir -p /var/www/html \
    && chown -R www-data:www-data /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/wp_setup.sh"]

