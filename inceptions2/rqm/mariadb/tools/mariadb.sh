#!/bin/sh

set -e

# Check if MariaDB is already initialized
if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]; then
	
echo "First time initialization MariaDB..."

mysqld_safe &

sleep 5
	
mysql -u root <<EOF

CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';

GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';

ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASSWORD}';

FLUSH PRIVILEGES;
EOF

mysqladmin -u root -p"${ROOT_PASSWORD}" shutdown

fi


exec mysqld_safe




