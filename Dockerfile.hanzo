# Hanzo Datastore — Columnar analytics engine + native ZAP duplex listener
# This is the production build. Uses docker/server/Dockerfile.alpine as source.
# Build: docker build -t ghcr.io/hanzoai/datastore:latest -f Dockerfile.hanzo docker/server/
#
# The image runs two processes in one container:
#   PID 1: hanzo-datastore server (HTTP 8123, native TCP 9000, replication 9009)
#   bg:    zap-bridge (ZAP duplex on TCP 9999, proxies to 127.0.0.1:9000)
#
# This replaces the deleted out-of-process zap-sidecar — native ZAP everywhere.
# Bridge source: cmd/zap-bridge (per-package go.mod, independent of C++ build).

ARG DS_VERSION=26.2.3.2
ARG REPO_CHANNEL=stable

# -- ZAP bridge build stage ----------------------------------------------------
# Compiles the Go zap-bridge binary for the target architecture. Independent
# of the ClickHouse C++ build — fast, cacheable, no cross-pollination.
FROM golang:1.26-alpine AS zap-builder
ARG TARGETARCH
WORKDIR /src
# Copy only what the bridge needs so unrelated repo changes don't bust cache.
COPY cmd/zap-bridge/ ./cmd/zap-bridge/
WORKDIR /src/cmd/zap-bridge
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH:-amd64} \
    go build -trimpath -ldflags='-s -w' -o /out/zap-bridge ./...

FROM ubuntu:22.04 AS glibc-donor
ARG TARGETARCH

RUN arch=${TARGETARCH:-amd64} \
    && case $arch in \
        amd64) rarch=x86_64 ;; \
        arm64) rarch=aarch64 ;; \
    esac \
    && ln -s "${rarch}-linux-gnu" /lib/linux-gnu \
    && case $arch in \
        amd64) ln /lib/linux-gnu/ld-linux-x86-64.so.2 /lib/linux-gnu/ld-2.35.so ;; \
        arm64) ln /lib/linux-gnu/ld-linux-aarch64.so.1 /lib/linux-gnu/ld-2.35.so ;; \
    esac

FROM alpine

LABEL maintainer="dev@hanzo.ai"
LABEL org.opencontainers.image.source="https://github.com/hanzoai/datastore"
LABEL org.opencontainers.image.description="Hanzo Datastore — columnar analytics engine"

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC \
    DATASTORE_CONFIG=/etc/hanzo-datastore-server/config.xml

COPY --from=glibc-donor /lib/linux-gnu/libc.so.6 /lib/linux-gnu/libdl.so.2 /lib/linux-gnu/libm.so.6 /lib/linux-gnu/libpthread.so.0 /lib/linux-gnu/librt.so.1 /lib/linux-gnu/libnss_dns.so.2 /lib/linux-gnu/libnss_files.so.2 /lib/linux-gnu/libresolv.so.2 /lib/linux-gnu/ld-2.35.so /lib/
COPY --from=glibc-donor /etc/nsswitch.conf /etc/
COPY docker/server/docker_related_config.xml /etc/hanzo-datastore-server/config.d/
COPY docker/server/datastore-port-override.xml /etc/hanzo-datastore-server/config.d/
COPY docker/server/hanzo-paths.xml /etc/hanzo-datastore-server/config.d/
COPY docker/server/entrypoint.sh /entrypoint.sh
COPY docker/server/nginx-header-proxy.conf /etc/nginx/http.d/datastore-proxy.conf

# Native ZAP bridge — single static binary. Started by entrypoint.sh in the
# background before clickhouse-server. Listens on :9999, proxies to
# 127.0.0.1:9000. See cmd/zap-bridge/main.go for the wire protocol.
COPY --from=zap-builder /out/zap-bridge /usr/local/bin/zap-bridge

ARG TARGETARCH
RUN arch=${TARGETARCH:-amd64} \
    && case $arch in \
        amd64) mkdir -p /lib64 && ln -sf /lib/ld-2.35.so /lib64/ld-linux-x86-64.so.2 ;; \
        arm64) ln -sf /lib/ld-2.35.so /lib/ld-linux-aarch64.so.1 ;; \
    esac

ARG DS_VERSION
ARG REPO_CHANNEL
ARG REPOSITORY="https://pkg.hanzo.ai/datastore/tgz/${REPO_CHANNEL}"
ARG PACKAGES="datastore-client datastore-server datastore-common-static"
ARG DIRECT_DOWNLOAD_URLS=""

ARG DEFAULT_UID="101"
ARG DEFAULT_GID="101"
RUN addgroup -S -g "${DEFAULT_GID}" hanzo-datastore && \
    adduser -S -h "/var/lib/hanzo-datastore" -s /bin/bash -G hanzo-datastore -g "Hanzo Datastore server" -u "${DEFAULT_UID}" hanzo-datastore

# Download, extract, and white-label binaries
RUN arch=${TARGETARCH:-amd64} \
    && cd /tmp \
    && if [ -n "${DIRECT_DOWNLOAD_URLS}" ]; then \
        echo "Installing from provided URLs: ${DIRECT_DOWNLOAD_URLS}" \
        && for url in $DIRECT_DOWNLOAD_URLS; do \
            echo "Get ${url}" \
            && wget -c -q "$url" \
        ; done \
    else \
        for package in ${PACKAGES}; do \
            echo "Get ${REPOSITORY}/${package}-${DS_VERSION}-${arch}.tgz" \
            && wget -c -q "${REPOSITORY}/${package}-${DS_VERSION}-${arch}.tgz" \
            && wget -c -q "${REPOSITORY}/${package}-${DS_VERSION}-${arch}.tgz.sha512" \
        ; done \
    fi \
    && cat *.tgz.sha512 | sed 's:/output/:/tmp/:' | sed 's/clickhouse-/datastore-/g' | sha512sum -c \
    && for file in *.tgz; do \
        if [ -f "$file" ]; then \
            echo "Unpacking $file"; \
            tar xvzf "$file" --strip-components=1 -C /; \
        fi \
    ; done \
    && rm /tmp/*.tgz /install -r \
    && chmod +x /entrypoint.sh \
    # tini is PID 1 — forwards SIGTERM to entire process group so both
    # the server (exec'd as PID 1's child) and zap-bridge (backgrounded
    # by entrypoint.sh) drain gracefully on shutdown. -g flag propagates
    # signals to the entire process group, not just the immediate child.
    && apk add --no-cache bash tzdata nginx tini \
    && cp /usr/share/zoneinfo/UTC /etc/localtime \
    && echo "UTC" > /etc/timezone \
    # White-label: rename upstream binary → hanzo-datastore
    && if [ -f /usr/bin/clickhouse ]; then mv /usr/bin/clickhouse /usr/bin/hanzo-datastore; fi \
    && ln -sf /usr/bin/hanzo-datastore /usr/bin/datastore \
    && ln -sf /usr/bin/hanzo-datastore /usr/bin/datastore-server \
    && ln -sf /usr/bin/hanzo-datastore /usr/bin/datastore-client \
    && ln -sf /usr/bin/hanzo-datastore /usr/bin/datastore-local \
    && ln -sf /usr/bin/hanzo-datastore /usr/bin/hanzo-datastore-server \
    && ln -sf /usr/bin/hanzo-datastore /usr/bin/hanzo-datastore-client \
    && ln -sf /usr/bin/hanzo-datastore /usr/bin/hanzo-datastore-local \
    && ln -sf /usr/bin/hanzo-datastore /usr/bin/hanzo-datastore-extract-from-config \
    && ln -sf /usr/bin/hanzo-datastore /usr/bin/hanzo-datastore-su \
    # Merge upstream config into hanzo-datastore paths (COPY may have pre-created dirs)
    && if [ -d /etc/clickhouse-server ]; then \
        cp -a /etc/clickhouse-server/* /etc/hanzo-datastore-server/ 2>/dev/null || true; \
        rm -rf /etc/clickhouse-server; fi \
    && if [ -d /etc/clickhouse-client ]; then \
        cp -a /etc/clickhouse-client/* /etc/hanzo-datastore-client/ 2>/dev/null || true; \
        rm -rf /etc/clickhouse-client; fi \
    # Pre-create nginx runtime dirs writable by hanzo-datastore user (for non-root operation)
    && mkdir -p /var/lib/nginx/logs /var/lib/nginx/tmp/client_body /var/lib/nginx/tmp/proxy \
        /var/lib/nginx/tmp/fastcgi /var/lib/nginx/tmp/uwsgi /var/lib/nginx/tmp/scgi /run/nginx \
    && chown -R hanzo-datastore:hanzo-datastore /var/lib/nginx /run/nginx

ARG DEFAULT_CLIENT_CONFIG_DIR="/etc/hanzo-datastore-client"
ARG DEFAULT_SERVER_CONFIG_DIR="/etc/hanzo-datastore-server"
ARG DEFAULT_DATA_DIR="/var/lib/hanzo-datastore"
ARG DEFAULT_LOG_DIR="/var/log/hanzo-datastore-server"

RUN mkdir -p \
      "${DEFAULT_DATA_DIR}" \
      "${DEFAULT_LOG_DIR}" \
      "${DEFAULT_CLIENT_CONFIG_DIR}" \
      "${DEFAULT_SERVER_CONFIG_DIR}/config.d" \
      "${DEFAULT_SERVER_CONFIG_DIR}/users.d" \
      /docker-entrypoint-initdb.d \
    && chown hanzo-datastore:hanzo-datastore "${DEFAULT_DATA_DIR}" \
    && chown root:hanzo-datastore "${DEFAULT_LOG_DIR}" \
    && chmod ugo+Xrw -R "${DEFAULT_DATA_DIR}" "${DEFAULT_LOG_DIR}" "${DEFAULT_CLIENT_CONFIG_DIR}" "${DEFAULT_SERVER_CONFIG_DIR}"

VOLUME "${DEFAULT_DATA_DIR}"
# 8123: HTTP   9000: native TCP   9009: replication   9999: native ZAP duplex
EXPOSE 9000 8123 9009 9999

HEALTHCHECK --interval=15s --timeout=3s --start-period=30s --retries=3 \
    CMD wget -qO- http://localhost:8123/ping || exit 1

# tini -g as PID 1 → forwards SIGTERM to the entire process group on
# shutdown. Without this, the bridge (backgrounded by entrypoint.sh)
# never receives SIGTERM when k8s sends one to the container; its
# graceful-drain logic is dead code. With tini -g, both the server
# (exec'd by entrypoint.sh) and the bridge (backgrounded) get the signal.
ENTRYPOINT ["/sbin/tini", "-g", "--", "/entrypoint.sh"]
