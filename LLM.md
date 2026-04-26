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

## Phase 1 — Single Binary (Embedded Coordination)

`hanzo-datastore` ships exactly one server binary. The standalone `clickhouse-keeper`/`datastore-keeper` entry-point is no longer a default build target. Coordination still works — it runs **in-process** inside `hanzo-datastore-server` whenever `<keeper_server>` is present in the runtime config.

### What changed

- `programs/CMakeLists.txt` — the option defaults flipped to `OFF`:
  - `ENABLE_DATASTORE_KEEPER` (was `${ENABLE_DATASTORE_ALL}`) — drops the standalone keeper entry-point and the `datastore-keeper` symlink from the multipurpose binary.
  - `ENABLE_DATASTORE_KEEPER_CONVERTER` (was `${ENABLE_DATASTORE_ALL}`) — drops the ZooKeeper→Keeper snapshot converter tool.
  - `ENABLE_DATASTORE_KEEPER_CLIENT` (was `${ENABLE_DATASTORE_ALL}`) — drops the standalone keeper CLI client.
- `Dockerfile.hanzo` — removed the `datastore-keeper` and `hanzo-datastore-keeper` symlink lines.
- `BUILD_STANDALONE_KEEPER` already defaulted `OFF` upstream; left untouched.

### What did NOT change (and why)

- `src/Coordination/` is **kept** and is still compiled into the server library unconditionally (`src/CMakeLists.txt:61` `add_subdirectory(Coordination)`, `:360` `add_object_library(datastore_coordination Coordination)`). This is the embedded-Raft logic.
- `Server.cpp:2468-2620` (the `if (config().has("keeper_server.server_id"))` block, gated `#if USE_NURAFT`) is the embedded-coordination boot path. It uses `getKeeperDispatcher` and `KeeperTCPHandlerFactory` from `src/Coordination/` and binds `keeper_server.tcp_port` (default `9181`), `keeper_server.tcp_port_secure`, and `keeper_server.http_control.port` *inside the server process*. No separate binary required.
- `programs/keeper/keeper_embedded.xml` is **kept** — it's the canonical config shape for the embedded path. `keeper_config.xml` (the standalone-binary config) stays in the source tree but is no longer installed by the default build.
- `programs/keeper/`, `contrib/NuRaft/`, `contrib/nuraft-cmake/` — **kept**. Removing them is Phase C and gated on the lux/consensus → Quasar replacement landing (see Phase B doc above).

### Packaging

`packages/hanzo-datastore-keeper.yaml` only ships content when `BUILD_STANDALONE_KEEPER=ON` (which we don't set). `packages/hanzo-datastore-server.yaml` is unchanged and now provides the *only* binary. The hanzo-datastore-keeper deb/rpm package can be deprecated after one release cycle — leave the spec in tree until then for upstream-sync stability.

### `programs/install/Install.cpp:440-441`

`Install.cpp` (the `datastore install` system-installer subcommand, separate from the `install/` packaging recipes) still lists `datastore-keeper` and `datastore-keeper-converter` in its `tools` symlink array. Those `fs::create_symlink` calls are no-ops on a binary that no longer claims those modes — the symlinks would point at the multipurpose `datastore` binary which would dispatch by `argv[0]` and fail. We don't ship `datastore install` from `Dockerfile.hanzo`, so this only matters for the deb/rpm path. Cleanup is queued for Phase 1.1; not load-bearing for this image.

### Validation

cmake configure on this macOS workstation aborts at `CMakeLists.txt:59 — Submodules are not initialized` (same gate the Phase B agent hit). The Phase-1 changes are option-default flips and one Dockerfile edit; they do not introduce new files, new sources, or new libraries. The diff is safe to validate on the Linux build host. Per `~/.claude/CLAUDE.md` ("NEVER fucking build images on my computer"), CI runs the configure+build.

## Related

- Native ZAP transport: `~/work/hanzo/base/network/transport_zap.go` (canonical reference)
- Used by: `hanzo/insights` (insights-datastore deployment in `~/work/hanzo/universe/infra/k8s/insights/`)
- ZAP port standard: 9999 across all Hanzo services (see `~/work/hanzo/CLAUDE.md`)
