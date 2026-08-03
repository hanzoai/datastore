# Hanzo Datastore

Hanzo's analytics database — a fork of ClickHouse with Hanzo-side overlays.

- **Repo**: https://github.com/hanzoai/datastore
- **Upstream**: https://github.com/ClickHouse/ClickHouse (`upstream` remote)
- **Image**: `ghcr.io/hanzoai/datastore`

## Architecture — S-Chain & the two-engine platform

Datastore is the **OLAP** half of Hanzo's data platform, and it separates storage
from compute. Its `MergeTree` parts are stored as objects on **Hanzo S3 /
"S-Chain"** — the SeaweedFS-fork storage substrate
([hanzoai/s3](https://github.com/hanzoai/s3)) — so stateless compute replicas share
one zero-copy copy of the data. This is a proven PoC: a 5M-row table whose storage
policy targets S-Chain — `system.parts` reports disk `seaweed` — and two compute
nodes scale out over a single physical copy via zero-copy replication. The gRPC and
Arrow Flight RPC surfaces are removed; the live query path is the native TCP protocol
(port 9000). **ZAP** (the Cap'n-Proto-derived RPC) is the intended replacement
transport — the server stub has landed, but it is not yet the query path. The planned
**OLTP** half is a decentralized SQL engine (SQLite/Base) — designed, not yet built.
The direction for both halves: ride S-Chain storage and move coordination from Raft to
**Quasar** (post-quantum, leaderless).

Design paper: `hanzo-datastore/` in [hanzoai/papers](https://github.com/hanzoai/papers).

## Benchmark vs official ClickHouse (measured, honest)

ClickBench (43 queries, 100M-row `hits` dataset), spark (aarch64), 4 runs/query,
warm. **opt** = our PGO+ThinLTO+BOLT `datastore.bolt` 26.6.1.1; **stock** = the
official `clickhouse` binary.

| Metric | Official ClickHouse | Hanzo Datastore (opt) | Delta |
|--------|--------------------|------------------------|-------|
| Peak RSS (under load) | 14.52 GB | 13.96 GB | **−3.8%** |
| Total query time (Σ per-query medians) | 16.83 s | 16.82 s | tied (+0.1%) |
| Per-query | — | faster on 8/43; median 0.95× | ~neutral |
| Binary, stripped | — | 398 MB | — |

**Honest verdict:** under production-scale load the optimization buys ~4% less peak
memory and is statistically tied on speed. **The scale matters and must be quoted:**
an earlier "~half the memory / much faster" figure was real but measured at **10M
rows**, where the removed XRay instrumentation + leaner binary are a large fraction
of a small working set. At **100M rows** the data dominates RSS, so the same fixed
savings shrink to ~4% and the speed win vanishes. Both are true at their scale —
never cite "half the memory" without "at 10M rows." Caveats on the 100M run: only 4
runs/query (per-query noise ±25%, so "tied" is within noise), one workload, one
machine, warm cache. The fork's real value is architectural (S-Chain storage
separation, consensus2 coordination, gRPC removed), not raw OLAP speed over stock.

## Stack

- **Server**: C++ (the ClickHouse codebase under `programs/`, `src/`, `base/`)
- **Build**: CMake → `datastore` binary

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 8123 | HTTP | ClickHouse HTTP interface |
| 9000 | TCP | ClickHouse native binary protocol |
| 9009 | TCP | ClickHouse interserver replication |
| 9181 | TCP | embedded keeper client port (when `<keeper_server>` is configured) |

## Layout

```
datastore/
├── programs/, src/, base/, contrib/  ← upstream ClickHouse C++
├── hanzo/                             ← Hanzo overlay: compose, config.xml, schema.sql
├── packages/, pkg/                    ← RPM/deb packaging (datastore-*.yaml)
├── docker/server/                     ← Hanzo image build (Dockerfile.ubuntu, white-labeled)
└── ci/                                ← upstream + Hanzo CI (Praktika)
```

## Build

```bash
# Local dev (compose):
cd hanzo && docker compose up

# CI: the release/master workflows run the "Docker server image" job
# (ci/jobs/docker_server.py) — it builds docker/server/Dockerfile.ubuntu from the
# source-built datastore debs and pushes ghcr.io/hanzoai/datastore (multi-arch).
```

## Upstream Sync

Automated via `.github/workflows/upstream-sync.yml` (weekly, Mon 06:00 UTC,
plus `workflow_dispatch`). The workflow fetches `upstream/master`, merges into
a fresh `upstream-sync/<UTC-date>` branch, and opens a **draft** PR — it
never auto-merges. On conflict the merge commit is pushed with conflict
markers intact and the draft PR is labelled `upstream-sync,conflict`.

There is exactly one upstream sync workflow. Do not add a second.

Net-new product files live under `hanzo/` (disjoint from upstream, so most syncs
land clean). White-labeling that edits upstream files in place — `docker/server/`,
`packages/`, `programs/server/config.xml`, top-level `CMakeLists.txt` — are the
watch areas for merge conflicts.

## Phase 1 — Single Binary (Embedded Coordination)

`datastore` ships exactly one server binary. The standalone `clickhouse-keeper`/`datastore-keeper` entry-point is no longer a default build target. Coordination still works — it runs **in-process** inside `datastore-server` whenever `<keeper_server>` is present in the runtime config.

### What changed

- `programs/CMakeLists.txt` — the option defaults flipped to `OFF`:
  - `ENABLE_DATASTORE_KEEPER` (was `${ENABLE_DATASTORE_ALL}`) — drops the standalone keeper entry-point and the `datastore-keeper` symlink from the multipurpose binary.
  - `ENABLE_DATASTORE_KEEPER_CONVERTER` (was `${ENABLE_DATASTORE_ALL}`) — drops the ZooKeeper→Keeper snapshot converter tool.
  - `ENABLE_DATASTORE_KEEPER_CLIENT` (was `${ENABLE_DATASTORE_ALL}`) — drops the standalone keeper CLI client.
- `docker/server/Dockerfile.ubuntu` — `PACKAGES` installs only `datastore-{client,server,common-static}`; the keeper package is not installed. The standalone "Docker keeper image" CI job (which built `docker/keeper/`) was retired — coordination is embedded.
- `BUILD_STANDALONE_KEEPER` already defaulted `OFF` upstream; left untouched.

### What did NOT change (and why)

- `src/Coordination/` is **kept** and is still compiled into the server library unconditionally (`src/CMakeLists.txt:61` `add_subdirectory(Coordination)`, `:360` `add_object_library(datastore_coordination Coordination)`). This is the embedded-Raft logic.
- `Server.cpp:2468-2620` (the `if (config().has("keeper_server.server_id"))` block, gated `#if USE_NURAFT`) is the embedded-coordination boot path. It uses `getKeeperDispatcher` and `KeeperTCPHandlerFactory` from `src/Coordination/` and binds `keeper_server.tcp_port` (default `9181`), `keeper_server.tcp_port_secure`, and `keeper_server.http_control.port` *inside the server process*. No separate binary required.
- `programs/keeper/keeper_embedded.xml` is **kept** — it's the canonical config shape for the embedded path. `keeper_config.xml` (the standalone-binary config) stays in the source tree but is no longer installed by the default build.
- `programs/keeper/`, `contrib/NuRaft/`, `contrib/nuraft-cmake/` — **kept**. Removing them is Phase C and gated on the lux/consensus → Quasar replacement landing (see Phase B doc above).

### Packaging

`packages/datastore-keeper.yaml` only ships content when `BUILD_STANDALONE_KEEPER=ON` (which we don't set). `packages/datastore-server.yaml` is unchanged and now provides the *only* binary. The datastore-keeper deb/rpm package can be deprecated after one release cycle — leave the spec in tree until then for upstream-sync stability.

### `programs/install/Install.cpp:440-441`

`Install.cpp` (the `datastore install` system-installer subcommand, separate from the `install/` packaging recipes) still lists `datastore-keeper` and `datastore-keeper-converter` in its `tools` symlink array. Those `fs::create_symlink` calls are no-ops on a binary that no longer claims those modes — the symlinks would point at the multipurpose `datastore` binary which would dispatch by `argv[0]` and fail. We don't ship `datastore install` from `Dockerfile`, so this only matters for the deb/rpm path. Cleanup is queued for Phase 1.1; not load-bearing for this image.

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

- `programs/keeper/`, `src/Coordination/`, `contrib/NuRaft/`, `contrib/nuraft-cmake/` — wait for the `keeper-replace` Blue (lux/consensus → Quasar) to land. Until then, ZooKeeper coordination is load-bearing for `Replicated*` engines. **Status: in progress — see "Coordination: Raft → Quasar" below.**
- HDFS, YTsaurus, MySQL — see RISKY notes above; they require `src/CMakeLists.txt` edits to gate currently-unconditional `add_headers_and_sources` / `add_object_library` calls. That edit is itself a Phase C task because it touches code on the upstream merge path.

## Coordination: Raft → Quasar (the NuRaft rip)

The fork is replacing the NuRaft consensus engine under Keeper with native Lux
**Quasar** (`libluxconsensus`, from [luxfi/consensus](https://github.com/luxfi/consensus)
`pkg/c`), linked into the C++ server. The **ZooKeeper API is kept** —
`KeeperStateMachine` over `KeeperStorage` is the contract `Replicated*` speaks; only
the *engine* (`raft_server`, leader election, asio peer transport) is replaced.

**Why it's tractable:** NuRaft coupling is contained in `src/Coordination/` (25
files); the only references elsewhere are `src/CMakeLists.txt` + `configure_config.cmake`
(build config, not code). Nothing in the query/storage/replication layers touches
`nuraft::` types. The join point is `KeeperStateMachine::commit(log_idx, buf)`:
NuRaft calls it today, the Quasar engine calls the identical method.

**Staged so each step lands under green tests (never break it all at once):**
1. **Engine proven + reusable** ✅ — `src/Coordination/QuasarKeeperConsensus.{h,cpp}`
   orders + commits batches through the real `KeeperStateMachine` (single-node:
   always-leader, 1-of-1 finality). Tested by `src/Coordination/examples/`
   (`keeper_quasar_poc`, `keeper_quasar_engine_test`), opt-in behind
   `ENABLE_EXAMPLES AND LUXCONSENSUS_DIR`, build-verified on a 26.6.1.1 host.
2. **Engine into `dbms` + `KeeperServer` cutover** — wire `libluxconsensus` as a
   contrib (`ch_contrib::luxconsensus`), move the engine `.cpp` into `dbms`, and
   make `KeeperServer` construct `QuasarKeeperConsensus` instead of
   `nuraft::raft_server` for single-node. The dispatcher contract it must satisfy
   (`putRequestBatch` async result, `isLeader`/`isLeaderAlive`/`getLeaderID`,
   `createSnapshot`, `applyConfigUpdate`, recovery flags) is mapped in the engine
   README. Gate on the full `gtest_coordination` suite green.
3. **Multi-node Quasar over ZAP** — replace NuRaft's asio peer transport with ZAP
   (the canonical Hanzo transport); leadership/membership derive from the Quasar
   validator set. This is what makes a real keeper *ensemble* run on Quasar.
4. **Excise residual `nuraft::` data types** (`buffer`/`log_entry`/`snapshot`/`ptr`
   — trivial containers, ~300 sites) and **delete `contrib/NuRaft` + `contrib/nuraft-cmake`**
   + the `src/CMakeLists.txt`/`configure_config.cmake` refs. End state: no `libnuraft`
   in the fork; coordination is Quasar-native end to end.

Stage 1 is merged. Stages 2–4 are the production cutover and are large (`KeeperServer`
is ~1350 lines welded to raft internals, incl. a `KeeperRaftServer : nuraft::raft_server`
subclass reaching protected members) — do them on a Linux build host with the
Coordination test suite as the gate, not on a laptop.

## Phase B — execution status

Branch `cleanup/phase-b` was created but **no deletions were committed**. Local cmake configure could not be validated:

- macOS AppleClang is rejected by `cmake/tools.cmake`; switching to Homebrew clang reaches the next gate.
- After installing GNU `findutils`, GNU `grep`, and pointing `OBJCOPY_PATH` at `llvm-objcopy`, configure reaches `CMakeLists.txt:59` and aborts: `Submodules are not initialized`. The repo's submodule set is multi-GB; initialization was not attempted under the rule "do not patch around configure failures".

Per the rule "If cmake configure fails after deletion, revert that group and report it as risky — don't try to patch around it", baseline configure failure means *no* group can be safely validated locally on this host. Deletion was therefore not executed; the plan above is the deliverable. Run the deletion + configure check on a Linux build host (CI runner with submodules initialized) before committing any of these `git rm -r` blocks.

## MinIO: purged from the docs, deliberately kept in the test harness

Hanzo S3 is SeaweedFS-derived and Apache-2.0 — never a MinIO fork. The
user-facing S3 documentation said otherwise and handed out `minioadmin` /
`minioadminpassword` as example credentials, so `docs/en/**` and the `src/**`
doc-strings that mirror it now use placeholders and a Hanzo S3 endpoint.

**The integration-test harness still runs MinIO, and that is the correct state
until someone ports it properly.** Do not `sed` it. What holds it:

- `minio==7.2.20` in `ci/docker/integration/runner/requirements.txt` is a real
  dependency: `helpers/cluster.py` does `from minio import Minio`, and 60 test
  files call 16 distinct methods on `cluster.minio_client` (`make_bucket`,
  `fput_object`, `set_bucket_policy`, `get_object_tags`, …). boto3 is already
  in the same requirements file, but its API is not method-for-method
  compatible, so this is a rewrite of the harness plus every call site.
- 136 tests pass `with_minio=True`; ~120 storage-config XMLs hardcode the
  fixture credential `ClickHouse_Minio_P@ssw0rd`.
- `compose/docker_compose_minio.yml` leans on MinIO-only surface: `--certs-dir`
  TLS (`test_s3_with_https`), `MINIO_PROMETHEUS_AUTH_TYPE`, a console address,
  and the `warehouse.minio` / `warehouse-rest.minio` aliases that exercise
  virtual-host-style bucket addressing. Hanzo S3 has equivalents
  (`-s3.domainName`, `/healthz`, `Hanzo_s3_*` metrics) but not the same flags.
- `proxy1`/`proxy2` come from `clickhouse/s3-proxy`, built in-repo at
  `ci/docker/integration/s3_proxy` but **pulled from a registry** at test time —
  a migration needs that image rebuilt and republished, which is a CI change,
  not a source change.

A port is a real project with a real acceptance test (the S3 integration suite
green), and it cannot be validated on an arm64 workstation: `ghcr.io/hanzoai/s3`
publishes linux/amd64 only, and the suite needs a built `datastore` binary. Run
it on a Linux CI host or not at all.

Also left: the MinIO-quirk comments in `src/IO/S3/**` and `src/IO/S3Common.h`
(the transient `InvalidPart` / `NO_SUCH_KEY` retries). They explain why live
retry logic exists, and they describe the server CI actually runs — deleting
them would delete the rationale and make the comment less true, not more.

`src/Parsers/obfuscateQueries.cpp` matches `minio` only as a prefix of the word
`minion` in a word list. Grep case-sensitively **and** with `\bminio` before
touching anything.

## Related

- Used by: `hanzo/insights` (insights-datastore deployment in `~/work/hanzo/universe/infra/k8s/insights/`)
