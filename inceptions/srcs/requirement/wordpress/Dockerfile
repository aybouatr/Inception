FROM php:8.2-fpm-alpine


WORKDIR /var/www/html

COPY config/www.conf /usr/local/etc/php-fpm.d/www.conf

COPY tools/wp_setup.sh /usr/local/bin/wp_setup.sh

RUN apk add --no-cache \
        mariadb-client \
        curl \
        wget \
        ca-certificates \
    && docker-php-ext-install mysqli pdo pdo_mysql

RUN wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

RUN mkdir -p /var/www/html \
    && mkdir -p /run/php


RUN chmod +x /usr/local/bin/wp_setup.sh

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/wp_setup.sh"]