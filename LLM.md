# Hanzo Datastore

Hanzo's analytics database — a fork of ClickHouse with Hanzo-side overlays.

- **Repo**: https://github.com/hanzoai/datastore
- **Upstream**: https://github.com/ClickHouse/ClickHouse (`upstream` remote)
- **Image**: `ghcr.io/hanzoai/datastore`

## Stack

- **Server**: C++ (the ClickHouse codebase under `programs/`, `src/`, `base/`)
- **Bridge**: Go (`cmd/zap-bridge/`) — ZAP duplex listener on `:9999` that proxies to ClickHouse native protocol on `127.0.0.1:9000`. Baked into the same image as the server. Single container, two processes.
- **Build**: CMake → `clickhouse` binary; Go → `zap-bridge` binary

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 8123 | HTTP | ClickHouse HTTP interface |
| 9000 | TCP | ClickHouse native binary protocol |
| 9009 | TCP | ClickHouse interserver replication |
| **9999** | **TCP** | **ZAP duplex (Hanzo canonical service port)** |
| 9181 | TCP | hanzo-datastore-keeper client port (separate image) |

## Layout

```
datastore/
├── programs/, src/, base/, contrib/  ← upstream ClickHouse C++
├── cmd/zap-bridge/                    ← Go ZAP→ClickHouse bridge
├── hanzo/                             ← Hanzo overlay: compose, config.xml, schema.sql
├── packages/, pkg/                    ← RPM/deb packaging
├── docker/, Dockerfile.hanzo          ← Hanzo image build
└── ci/                                ← upstream + Hanzo CI
```

## Build

```bash
# Local dev (compose):
cd hanzo && docker compose up

# CI: hanzoai/.github/.github/workflows/docker-build.yml@main
# pushes to ghcr.io/hanzoai/datastore (multi-arch)
```

## Upstream Sync

`upstream` remote is `ClickHouse/ClickHouse`. Periodic merges land via a `merge-clickhouse-updates` branch with manual conflict resolution; the Hanzo overlay (`hanzo/`, `cmd/zap-bridge/`, `Dockerfile.hanzo`) is kept distinct from upstream paths to minimize collisions.

## Related

- Native ZAP transport: `~/work/hanzo/base/network/transport_zap.go` (canonical reference)
- Used by: `hanzo/insights` (insights-datastore deployment in `~/work/hanzo/universe/infra/k8s/insights/`)
- ZAP port standard: 9999 across all Hanzo services (see `~/work/hanzo/CLAUDE.md`)
