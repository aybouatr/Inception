FROM alpine:latest

RUN apk add --no-cache nginx openssl

RUN mkdir -p /etc/nginx/ssl \
    && openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/server.key \
        -out /etc/nginx/ssl/server.crt \
        -subj "/C=MA/ST=Casablanca/L=Casablanca/O=42/OU=Inception/CN=aybouatr.42.fr"

COPY ./config/nginx.conf /etc/nginx/http.d/default.conf

RUN mkdir -p /var/www/html

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]

# old version of the nginx Dockerfile, kept for reference

# FROM alpine:latest

# RUN apk add --no-cache nginx openssl


# RUN mkdir -p /etc/nginx/ssl && \
#     openssl req -x509 -nodes -days 365 \
#         -newkey rsa:2048 \
#         -keyout /etc/nginx/ssl/server.key \
#         -out /etc/nginx/ssl/server.crt \
#         -subj "/C=MA/ST=Casablanca/L=Casablanca/O=42/OU=Inception/CN=localhost"


# COPY ./config/nginx.conf /etc/nginx/http.d/default.conf


# RUN mkdir -p /var/www/html

# EXPOSE 443

# CMD ["nginx", "-g", "daemon off;"]