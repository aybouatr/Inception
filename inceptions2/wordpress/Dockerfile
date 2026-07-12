FROM alpine:3.22

RUN apk add --no-cache \
    nginx \
    php84 \
    php84-fpm \
    php84-mysqli \
    php84-curl \
    php84-mbstring \
    php84-xml \
    php84-gd \
    php84-zip \
    php84-opcache \
    php84-session \
    php84-fileinfo \
    php84-exif \
    php84-intl \
    curl \
    unzip

RUN mkdir -p /run/nginx

COPY nginx.conf /etc/nginx/nginx.conf
COPY www.conf /etc/php84/php-fpm.d/www.conf

WORKDIR /var/www/html

CMD ["sh", "-c", "php-fpm84 && nginx -g 'daemon off;'"]