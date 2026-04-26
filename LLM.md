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

## Disabled External Engines (Phase A landed)

Hanzo Datastore is OLAP-only. External system integrations (stream brokers, foreign-DB read engines, foreign-DB CDC) are out of scope and disabled at build time. Each engine retains its source tree (gated by a `USE_*` macro) so upstream merges stay clean; the corresponding `ENABLE_*` CMake option defaults `OFF`. No runtime config re-enables them.

| Engine / Source | CMake option | Source tree | Contrib subtree |
|-----------------|--------------|-------------|-----------------|
| Kafka stream | `ENABLE_KAFKA` | `src/Storages/Kafka/` | `contrib/librdkafka{,-cmake}/`, `contrib/cppkafka{,-cmake}/`, `contrib/libgsasl{,-cmake}/` |
| RabbitMQ | `ENABLE_AMQPCPP` | `src/Storages/RabbitMQ/` | `contrib/AMQP-CPP/`, `contrib/amqpcpp-cmake/` |
| MySQL engine + dict + DB | `ENABLE_MYSQL` | `src/Storages/MySQL/`, `src/Databases/MySQL/`, `src/Core/MySQL/`, `src/Interpreters/MySQL/`, `src/Dictionaries/MySQLDictionarySource.{cpp,h}`, `src/Storages/StorageMySQL.{cpp,h}` | `contrib/mariadb-connector-c{,-cmake}/` |
| PostgreSQL engine + MaterializedPostgreSQL CDC + dict | `ENABLE_LIBPQXX` | `src/Storages/PostgreSQL/`, `src/Databases/PostgreSQL/`, `src/Core/PostgreSQL/`, `src/Dictionaries/PostgreSQLDictionarySource.{cpp,h}`, `src/Storages/StoragePostgreSQL.{cpp,h}` | `contrib/libpqxx{,-cmake}/`, `contrib/postgres{,-cmake}/` |
| MongoDB engine + dict | `USE_MONGODB` | `src/Storages/StorageMongoDB.{cpp,h}`, `src/Storages/StorageMongoDBPocoLegacy.cpp`, `src/Dictionaries/MongoDBDictionarySource.{cpp,h}` | `contrib/mongo-c-driver{,-cmake}/`, `contrib/mongo-cxx-driver{,-cmake}/` |
| HDFS storage | `ENABLE_HDFS` | `src/Storages/ObjectStorage/HDFS/`, `src/Disks/DiskObjectStorage/ObjectStorages/HDFS/` | `contrib/libhdfs3{,-cmake}/` |
| Hive metastore | `ENABLE_HIVE` | `src/Storages/Hive/`, `src/Processors/Formats/Impl/HiveTextRowInputFormat.{cpp,h}` | `contrib/hive-metastore{,-cmake}/` |
| Cassandra dict | `ENABLE_CASSANDRA` | `src/Dictionaries/CassandraDictionarySource.{cpp,h}`, `src/Dictionaries/CassandraHelpers.{cpp,h}`, `src/Dictionaries/CassandraSource.{cpp,h}` | `contrib/cassandra{,-cmake}/` |
| YTsaurus storage + dict + table fn | `ENABLE_YTSAURUS` | `src/Storages/YTsaurus/`, `src/Core/YTsaurus/`, `src/Dictionaries/YTsaurusDictionarySource.{cpp,h}`, `src/Processors/Sources/YTsaurusSource.{cpp,h}` | (no dedicated contrib) |

Engines that are **kept** because they belong to an OLAP/HTTP/object-storage shape: `MergeTree` family, `Replicated*`, `Distributed`, `File`, `URL`, `S3`, `ObjectStorage`, `ObjectStorageQueue` (S3 SQS-style queue, in-tree), `Memory`, `Log`, `View`, `MaterializedView`, `RocksDB`, Hanzo DocDB-shaped engines, ZooKeeper/Keeper coordination, `Dictionary` engine (sans foreign-DB sources), `NATS` (Hanzo PubSub transport), `FileLog` (local-file, `USE_FILELOG=1` on Linux). Kerberos client auth (`Access/GSSAcceptor`, `Access/KerberosInit`) is server-side and unrelated to disabled engines — `contrib/krb5{,-cmake}/` and `contrib/cyrus-sasl{,-cmake}/` MUST be kept.

## Phase B — Source Deletion Plan (NOT executed)

Phase A flipped defaults to OFF; Phase B physically deletes the disabled source/contrib trees. This conflicts with the Phase A note "Source trees stay … to keep upstream merges clean" — accept the conflict cost in exchange for a smaller compile surface and faster upstream sync (less code to merge).

Cross-reference (`src/CMakeLists.txt`): some engine source trees are added unconditionally and require a CMake gate edit before deletion. Those rows are flagged `risky` below.

```sh
# disabled: kafka  (gated: if (TARGET ch_contrib::rdkafka) at src/CMakeLists.txt:129)
git rm -r src/Storages/Kafka
git rm -r contrib/librdkafka contrib/librdkafka-cmake
git rm -r contrib/cppkafka contrib/cppkafka-cmake
git rm -r contrib/libgsasl contrib/libgsasl-cmake   # only consumers were rdkafka + libhdfs3

# disabled: rabbitmq  (gated: if (TARGET ch_contrib::amqp_cpp) at src/CMakeLists.txt:154)
git rm -r src/Storages/RabbitMQ
git rm -r contrib/AMQP-CPP contrib/amqpcpp-cmake

# disabled: hive  (gated: if (TARGET ch_contrib::hivemetastore) at src/CMakeLists.txt:189)
git rm -r src/Storages/Hive
git rm -r src/Processors/Formats/Impl/HiveTextRowInputFormat.cpp src/Processors/Formats/Impl/HiveTextRowInputFormat.h
git rm -r contrib/hive-metastore contrib/hive-metastore-cmake

# disabled: postgresql  (gated: if (USE_LIBPQXX) at src/CMakeLists.txt:158)
git rm -r src/Storages/PostgreSQL src/Databases/PostgreSQL src/Core/PostgreSQL
git rm    src/Dictionaries/PostgreSQLDictionarySource.cpp src/Dictionaries/PostgreSQLDictionarySource.h
git rm    src/Storages/StoragePostgreSQL.cpp src/Storages/StoragePostgreSQL.h
git rm    src/Processors/Sources/PostgreSQLSource.cpp src/Processors/Sources/PostgreSQLSource.h
git rm -r contrib/libpqxx contrib/libpqxx-cmake contrib/postgres contrib/postgres-cmake

# disabled: mongodb  (gated: if (USE_MONGODB) at contrib/CMakeLists.txt:172; src files use #if USE_MONGODB)
git rm    src/Storages/StorageMongoDB.cpp src/Storages/StorageMongoDB.h src/Storages/StorageMongoDBPocoLegacy.cpp
git rm    src/Dictionaries/MongoDBDictionarySource.cpp src/Dictionaries/MongoDBDictionarySource.h
git rm    src/Processors/Sources/MongoDBSource.cpp src/Processors/Sources/MongoDBSource.h
git rm    src/TableFunctions/TableFunctionMongoDB.cpp
git rm -r contrib/mongo-c-driver contrib/mongo-c-driver-cmake contrib/mongo-cxx-driver contrib/mongo-cxx-driver-cmake

# disabled: cassandra  (dict source uses #if USE_CASSANDRA; contrib has its own gate)
git rm    src/Dictionaries/CassandraDictionarySource.cpp src/Dictionaries/CassandraDictionarySource.h
git rm    src/Dictionaries/CassandraHelpers.cpp src/Dictionaries/CassandraHelpers.h
git rm    src/Dictionaries/CassandraSource.cpp src/Dictionaries/CassandraSource.h
git rm -r contrib/cassandra contrib/cassandra-cmake

# disabled: hdfs  (RISKY: Storages/ObjectStorage/HDFS added unconditionally at src/CMakeLists.txt:140)
# Requires gating add_headers_and_sources(dbms Storages/ObjectStorage/HDFS) under TARGET ch_contrib::hdfs first.
git rm -r src/Storages/ObjectStorage/HDFS
git rm -r src/Disks/DiskObjectStorage/ObjectStorages/HDFS
git rm -r contrib/libhdfs3 contrib/libhdfs3-cmake

# disabled: ytsaurus  (RISKY: Core/YTsaurus and Storages/YTsaurus added unconditionally at src/CMakeLists.txt:151-152)
# Requires gating both lines under if (ENABLE_YTSAURUS) first.
git rm -r src/Core/YTsaurus src/Storages/YTsaurus
git rm    src/Dictionaries/YTsaurusDictionarySource.cpp src/Dictionaries/YTsaurusDictionarySource.h
git rm    src/Processors/Sources/YTsaurusSource.cpp src/Processors/Sources/YTsaurusSource.h

# disabled: mysql  (RISKY: 4 add_object_library() calls unconditional at src/CMakeLists.txt:273,278,288,294;
# also blocked by ch::mysqlxx hard-linking ch_contrib::mariadbclient — used by Dictionaries/Embedded
# and other always-on call sites. Requires either dropping mysqlxx contract or gating it on ENABLE_MYSQL.)
# DEFER until ch::mysqlxx is detached from mariadbclient.
git rm -r src/Storages/MySQL src/Databases/MySQL src/Core/MySQL src/Interpreters/MySQL
git rm    src/Storages/StorageMySQL.cpp src/Storages/StorageMySQL.h
git rm    src/Dictionaries/MySQLDictionarySource.cpp src/Dictionaries/MySQLDictionarySource.h
git rm    src/Processors/Sources/MySQLSource.cpp
git rm -r contrib/mariadb-connector-c contrib/mariadb-connector-c-cmake
```

## Phase C — deferred deletions (do NOT do in Phase B)

- `programs/keeper/`, `src/Coordination/`, `contrib/NuRaft/`, `contrib/nuraft-cmake/` — wait for the `keeper-replace` Blue (lux/consensus → Quasar) to land. Until then, ZooKeeper coordination is load-bearing for `Replicated*` engines.
- HDFS, YTsaurus, MySQL — see RISKY notes above; they require `src/CMakeLists.txt` edits to gate currently-unconditional `add_headers_and_sources` / `add_object_library` calls. That edit is itself a Phase C task because it touches code on the upstream merge path.

## Phase B — execution status

Branch `cleanup/phase-b` was created but **no deletions were committed**. Local cmake configure could not be validated:

- macOS AppleClang is rejected by `cmake/tools.cmake`; switching to Homebrew clang reaches the next gate.
- After installing GNU `findutils`, GNU `grep`, and pointing `OBJCOPY_PATH` at `llvm-objcopy`, configure reaches `CMakeLists.txt:59` and aborts: `Submodules are not initialized`. The repo's submodule set is multi-GB; initialization was not attempted under the rule "do not patch around configure failures".

Per the rule "If cmake configure fails after deletion, revert that group and report it as risky — don't try to patch around it", baseline configure failure means *no* group can be safely validated locally on this host. Deletion was therefore not executed; the plan above is the deliverable. Run the deletion + configure check on a Linux build host (CI runner with submodules initialized) before committing any of these `git rm -r` blocks.

## Related

- Native ZAP transport: `~/work/hanzo/base/network/transport_zap.go` (canonical reference)
- Used by: `hanzo/insights` (insights-datastore deployment in `~/work/hanzo/universe/infra/k8s/insights/`)
- ZAP port standard: 9999 across all Hanzo services (see `~/work/hanzo/CLAUDE.md`)
