#!/bin/sh

set -e

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
chmod 755 /run/mysqld

chown -R mysql:mysql /var/lib/mysql

# Create runtime directory
chown -R mysql:mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql

# First initialization
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "First time initialization MariaDB..."

    # Initialize the data directory
    mariadb-install-db \
        --user=mysql \
        --datadir=/var/lib/mysql

    # Start MariaDB in the background
    mysqld_safe --user=mysql &
    
    # Wait until MariaDB is ready
    until mariadb-admin ping --silent
    do
        sleep 1
    done

    echo "MariaDB started."

    # Configure database and users
    mariadb -u root << EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';

GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';

ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

FLUSH PRIVILEGES;
EOF

    # Stop temporary server
    mariadb-admin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown

    echo "Initialization completed."
fi

echo "Starting MariaDB..."

exec mysqld_safe --user=mysql