# docker build -t datastore/docs-builder .
FROM node:22-bookworm-slim

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    git \
    openssh-client \
    python3 \
    python3-venv \
    rsync \
    curl \
    ca-certificates \
    build-essential && \
    rm -rf /var/lib/apt/lists/*

ARG CACHE_INVALIDATOR=0

# Create a specific user and group
RUN groupadd -r datastore && \
    useradd -r -g datastore -m -d /home/datastore -s /sbin/nologin -c "Datastore user" datastore

RUN npm install -g npm@11 mint@latest
ENV HOME=/opt/datastore-docs

# Create directory with specific ownership
RUN mkdir -p /opt/datastore-docs && \
    chown datastore:datastore /opt/datastore-docs && \
    chmod -R a+rw /opt/datastore-docs/

# Set working directory
WORKDIR /
