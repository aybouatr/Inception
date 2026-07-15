FROM debian:bookworm

WORKDIR /var/www/html

# Install PHP, PHP-FPM, MariaDB client, curl and utilities
RUN apt-get update && \
    apt-get install -y \
        php8.2 \
        php8.2-fpm \
        php8.2-mysql \
        php8.2-curl \
        php8.2-cli \
        php8.2-xml \
        php8.2-mbstring \
        php8.2-zip \
        mariadb-client \
        curl \
        unzip \
        bash && \
    rm -rf /var/lib/apt/lists/*

# Install WP-CLI
RUN curl -o /usr/local/bin/wp \
    https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp

# Copy PHP-FPM pool configuration
COPY config/www.conf /etc/php/8.2/fpm/pool.d/www.conf

# Copy startup script
COPY tools/wp_setup.sh /usr/local/bin/wp_setup.sh

RUN chmod +x /usr/local/bin/wp_setup.sh

# Create runtime directories
RUN mkdir -p /run/php /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/wp_setup.sh"]