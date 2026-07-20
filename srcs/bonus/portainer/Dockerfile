FROM debian:bookworm-slim

ENV PORTAINER_VERSION=2.39.5

RUN apt-get update && \
    apt-get install -y \
        ca-certificates \
        curl \
        tar && \
    rm -rf /var/lib/apt/lists/*

RUN curl -L \
    https://github.com/portainer/portainer/releases/download/${PORTAINER_VERSION}/portainer-${PORTAINER_VERSION}-linux-amd64.tar.gz \
    -o /tmp/portainer.tar.gz && \
    tar -xzf /tmp/portainer.tar.gz -C / && \
    rm /tmp/portainer.tar.gz

RUN mkdir -p /data

EXPOSE 9443

VOLUME ["/data"]

ENTRYPOINT ["/portainer/portainer"]