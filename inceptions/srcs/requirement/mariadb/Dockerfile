FROM alpine:latest

RUN apk add --no-cache \
    mariadb \
    mariadb-client

COPY conf/my.cnf /etc/my.cnf
COPY tools/setup.sh /usr/local/bin/setup.sh

RUN chmod +x /usr/local/bin/setup.sh \
    && mkdir -p /run/mysqld /var/lib/mysql /var/log/mysql \
    && chown -R mysql:mysql /run/mysqld /var/lib/mysql /var/log/mysql


VOLUME /var/lib/mysql

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/setup.sh"]