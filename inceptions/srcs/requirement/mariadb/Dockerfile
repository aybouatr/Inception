FROM alpine:latest

RUN apk add --no-cache \
    mariadb \
    mariadb-client

COPY tools/setup.sh /usr/local/bin/setup.sh

RUN chmod +x /usr/local/bin/setup.sh

VOLUME /var/lib/mysql

EXPOSE 3306

CMD ["/usr/local/bin/setup.sh"]