# Hanzo Datastore — ClickHouse 26.5 columnar analytics engine + native ZAP duplex listener.
# One image, multi-arch (amd64+arm64), built on the upstream 26.5 release.
#   PID-adjacent: hanzo-datastore server (HTTP 8123, native 9000, replication 9009, keeper 9181)
#   background:   zap-bridge (ZAP duplex on TCP 9999, proxies to 127.0.0.1:9000)
ARG DS_VERSION=26.5.3.1

# zap-bridge: Go, per-arch, independent of the C++ server.
FROM golang:1.26-alpine AS zap-builder
ARG TARGETARCH
WORKDIR /src/cmd/zap-bridge
COPY cmd/zap-bridge/ ./
RUN go mod download && CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH:-amd64} \
    go build -trimpath -ldflags='-s -w' -o /out/zap-bridge ./...

FROM clickhouse/clickhouse-server:26.5
LABEL maintainer="dev@hanzo.ai"
LABEL org.opencontainers.image.source="https://github.com/hanzoai/datastore"
LABEL org.opencontainers.image.description="Hanzo Datastore — columnar analytics engine (ClickHouse 26.5 + native ZAP duplex)"

# White-label: the server binary is hanzo-datastore. Internal clickhouse-* symlinks
# keep the upstream entrypoint working; the product surface is datastore.
RUN set -eux; \
    mv /usr/bin/clickhouse /usr/bin/hanzo-datastore; \
    for n in clickhouse clickhouse-server clickhouse-client clickhouse-local \
             datastore datastore-server datastore-client datastore-local \
             hanzo-datastore-server hanzo-datastore-client hanzo-datastore-local; do \
        ln -sf /usr/bin/hanzo-datastore /usr/bin/$n; \
    done

COPY --from=zap-builder /out/zap-bridge /usr/local/bin/zap-bridge

# Wrapper: start zap-bridge (:9999) alongside the upstream server entrypoint.
RUN printf '#!/bin/bash\nset -e\n/usr/local/bin/zap-bridge &\nexec /entrypoint.sh "$@"\n' \
      > /hanzo-entrypoint.sh && chmod +x /hanzo-entrypoint.sh

ENV DATASTORE_CONFIG=/etc/clickhouse-server/config.xml
EXPOSE 8123 9000 9009 9181 9999
HEALTHCHECK --interval=15s --timeout=3s --start-period=30s --retries=3 \
    CMD wget -qO- http://localhost:8123/ping || exit 1
ENTRYPOINT ["/hanzo-entrypoint.sh"]
