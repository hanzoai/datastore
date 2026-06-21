# Hanzo Datastore — ClickHouse 26.5, white-labeled. Multi-arch (amd64+arm64).
# Built on the upstream release image; the product binary is hanzo-datastore and
# the product surface is `datastore <app>` (server/client/local). The clickhouse-*
# names remain as symlinks so the upstream entrypoint keeps working unchanged.
FROM clickhouse/clickhouse-server:26.5

LABEL org.opencontainers.image.title="Hanzo Datastore"
LABEL org.opencontainers.image.description="Columnar analytics engine (ClickHouse 26.5, white-labeled)"
LABEL org.opencontainers.image.source="https://github.com/hanzoai/datastore"
LABEL maintainer="dev@hanzo.ai"

RUN mv /usr/bin/clickhouse /usr/bin/hanzo-datastore \
    && for n in clickhouse clickhouse-server clickhouse-client clickhouse-local datastore; do \
         ln -sf /usr/bin/hanzo-datastore /usr/bin/"$n"; \
       done
