#!/bin/sh
set -e

echo "Starting MariaDB setup..."

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

MYSQL_DATABASE=${MYSQL_DATABASE:-wordpress}
MYSQL_USER=${MYSQL_USER:-wordpress}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-wordpress}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-root}

# Initialize MariaDB only once
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB..."

    mariadb-install-db \
        --user=mysql \
        --datadir=/var/lib/mysql

    echo "Starting temporary MariaDB..."

    mariadbd \
        --user=mysql \
        --bind-address=127.0.0.1 \
        --port=3306 &
    pid="$!"

    echo "Waiting for MariaDB..."

    until mariadb-admin ping --silent; do
        sleep 1
    done

    echo "Creating database..."

    mariadb <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';

GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';

FLUSH PRIVILEGES;
EOF

    echo "Stopping temporary server..."

    mariadb-admin -uroot -p"${MYSQL_ROOT_PASSWORD}" shutdown

    wait "$pid"
fi

echo "Starting MariaDB..."

exec mariadbd \
    --user=mysql \
    --bind-address=0.0.0.0 \
    --port=3306