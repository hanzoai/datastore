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

# CI: .hanzo/workflows/cicd.yml calls hanzoai/ci, which reads the root hanzo.yml
# and builds the repo-root Dockerfile from source, publishing
# ghcr.io/hanzoai/datastore (linux/amd64). See hanzo.yml for why it is the root
# Dockerfile and not docker/server/, and why there is no deploy block.
```

## Upstream Sync

Automated via `.hanzo/workflows/upstream-sync.yml` (weekly, Mon 06:00 UTC, plus
`workflow_dispatch`). The workflow fetches `upstream/master`, merges it onto an
`upstream-sync/<upstream-commit>` branch, and opens a `WIP:` pull request on
git.hanzo.ai — it never auto-merges. On conflict the merge commit is pushed with
the markers intact and the pull request lists the conflicting files. Naming the
branch after the upstream commit makes a re-run on an unchanged upstream head a
no-op rather than a duplicate proposal.

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

## Related

- Used by: `hanzo/insights` (insights-datastore deployment in `~/work/hanzo/universe/infra/k8s/insights/`)

## Operating this thing (2026-08-09, learned the hard way)

**There is no client binary.** Ours is named ours, so `clickhouse-client` does not exist in the
pod. Query it over HTTP from an `insights-web` pod:

    http://datastore:8123/?query=<urlencoded>&user=$DATASTORE_USER&password=$DATASTORE_PASSWORD

**Logs are NOT on the PVC.** Only `/var/lib/hanzo-datastore` is persisted; the server logs to
`/var/log/hanzo-datastore-server/` on the container filesystem, so a crashing container takes its
error log with it and `kubectl logs` shows only the pre-logger startup lines. To see a startup
failure, run a throwaway pod with the same image and configmap plus
`<logger><console>1</console></logger>` — that is the only way to read the real exception.

**Two config faults that make it refuse to start**, both found in production
(`universe/charts/app/values/hanzo/datastore.yaml`, Helm-managed — a `kubectl` edit to the
ConfigMap IS reverted by GitOps within about a minute):

- **`--` is illegal inside an XML comment.** Prose explaining a previous outage used it six times
  across `log-retention.xml` and `memory.xml`; the server dies with `SAXParseException: Invalid
  token`. The running process holds its config in memory, so this stays invisible until a restart.
  Validate every embedded document parses before pushing.
- **`background_pool_size` below the mutation threshold.** Setting it to 4 makes the server exit 36:
  `number_of_free_entries_in_pool_to_execute_mutation` defaults to 20 and must be LOWER than the
  pool. It also starves the merges you need most.

**The memory death spiral.** `datastore-0` wedged above its own `max_server_memory_usage`
(10.80 GiB of a 12Gi limit) and refused EVERY query including `SELECT 1`, so all analytics failed
while the site still served 200. Mechanism: merges need memory → memory exhausted → merges stall →
parts accumulate → per-part metadata consumes more memory. `event.metric_30m` reached ~126k of
~126.7k total active parts. The tiny parts were the SYMPTOM, not a bad writer — recent parts were
~4,600 rows each. A restart clears it and it drains on its own (~2.4 parts/sec, memory falling).
Reducing the merge pool makes it worse, not better. The node has no headroom: memory limits at
161% overcommit, 12Gi limit against ~13.6Gi allocatable, so raising it in place is not available.

**Migrations.** `migrate_datastore --check` failing is not always about migrations — it fails the
same way when the server is unreachable or wedged, so read the error before concluding. As of
2026-08-09 there were 83 genuinely unapplied migrations (last applied `0223_event_name_backmap`),
several of them materializations over a 15.5 GiB table; drain the parts backlog first and classify
additive-vs-destructive before applying.

## The headers are translated by nginx, not emitted by the engine

There is an **nginx header-translation proxy inside the container** (`Server: nginx`, master + 2
workers on 8123, engine demoted to 8124). It rewrites response headers from the engine's spelling
to ours. So seeing `X-Datastore-*` on the wire is NOT evidence that a renamed binary shipped — it
translated five and missed three, which is where `x-clickhouse-exception-tag` came from. The
translation is complete now (zero `x-clickhouse-*`, error path included), but `Server: nginx`
remains because stock nginx cannot rename that header. It goes away when the proxy does.

**No published image contains the rename.** The newest revision-labelled build is 2026-03-11; the
rename commits are 2026-06-21. Every March revision is unreachable — a later re-import of the
overlay orphaned that history. `26.6.1.1`/`26.6` carry no revision label and are a laptop
hand-build (arm64, `/etc/datastore-server` paths, `single_binary_location_url=localhost:8899`);
do not pin them. The fast rebuild path is dead (`pkg.hanzo.ai` is now an npm proxy, tarball 404s),
so a from-source build is the only route: ~245 min against a runner ceiling that was 3h and is now
6h. Two earlier runs died at 190.5 and 193.5 min and were misread as OOM — they were the ceiling.
**26.2 → 26.7 is a one-way door** (data path AND part format); treat it as a reviewed migration.

## subPath mounts do not refresh — and a missing key blocks startup

A ConfigMap key deleted while a `subPath` mount still names it makes the next pod stop at
ContainerCreating. It is invisible until something restarts the pod, because subPath mounts never
refresh. This nearly bit us: `f2ec4616c` removed the `paths.xml` key and left the mount. If you
delete a config key, delete its mount in the same change.

## Two real bugs the rename left, worth knowing the shape of

- `src/Client/BuzzHouse/Generator/ExternalIntegrations.cpp` read `is_clickhouse`, a member that
  exists nowhere (it is `is_datastore` three lines away). It compiles only because
  `ENABLE_BUZZHOUSE` is off — turning it on does not build.
- `src/Common/FileChecker.cpp` wrote `{"datastore": …}` but read only `datastore`/`yandex`. A
  directory written by a build that said `clickhouse` reads back as an **empty file list** — no
  error, just a checker that believes the table has no data.

## The rename crossed the contract line in places, and those are breaking now

Renaming a name is safe; renaming a contract is not. Already throwing or broken:
`SET dialect='clickhouse'`; the dictionary source registers only as `datastore`, so
`SOURCE(CLICKHOUSE(…))` and `<source><clickhouse>` throw (48 examples in `FunctionDocumentation`
are now invalid SQL and are served through `system.functions`); Prometheus metric prefixes are
`Datastore*`, so any dashboard matching `ClickHouse*` is broken; the SSH-signature namespace is
`datastore`, so SSH-key auth will not interop with upstream clients. Decide these deliberately —
aliases are cheap where interop matters.

## ZAP is present but is a port-opener, not a transport

`contrib/zap` (debranded Cap'n Proto) and `src/Server/ZapServer.{h,cpp}` (181 lines) exist, but the
server serves a **null bootstrap capability** — no schema, no method, no SQL — and is compiled out
(`USE_ZAP=0`, submodule empty). The `ProtocolServerAdapter` plumbing is done (~70 lines); that was
never the expensive half. For scale: the gRPC server deleted to make room was 2,023 lines plus a
227-line schema.

The decisive constraint: this stub speaks **capnp-family** RPC, while `hanzoai/s3` and the Hanzo Go
services speak the **envelope** wire, and there is no C++ envelope runtime (zapgen emits Go only).
Honest cost: demo-grade first cut 8-15 engineer-days; parity with the deleted gRPC transport
+30-60; actually wire-compatible with the Go services +20-40 and needs a C++ runtime nobody has
written yet.

## The from-source build fails on a macro the rename half-renamed

`CMakeLists.txt` sets `DATASTORE_CLOUD` and `src/Common/config.h.in` emits it as
`#cmakedefine01 DATASTORE_CLOUD`, so that is the only spelling that reaches the preprocessor.
Eighteen `#if` sites in `src/` still read `CLICKHOUSE_CLOUD`, which is defined nowhere. This tree
builds with `-Werror,-Wundef`, so an undefined macro in `#if` is a hard error, not a false branch.

The trap is *when* it lands. Ninja reaches `Storages/` about two hours in, so the failure looks
like the build died of exhaustion — and it was twice answered as memory (compile jobs 6 → 3) and
once as a timeout. It is neither. Read the log for `is not defined, evaluates to 0` before you
believe any resource theory.

The definition side of the rename was already complete — CMake variable, config template and the
contrib guards all say `DATASTORE_CLOUD`. Only the reads were missed.

Check the whole class in one pass, because each miss costs a two-hour round trip:

    git grep -hoE '#\s*(if|ifdef|ifndef|elif)[^/]*\b(CLICKHOUSE|HANZO)_[A-Z_]+' -- src/ programs/ base/ utils/
    comm -23 <(git grep -hoE '#\s*(if|elif)[^/]*\bDATASTORE_[A-Z_]+' -- src/ | grep -oE 'DATASTORE_[A-Z_]+' | sort -u) \
             <(grep -oE 'DATASTORE_[A-Z_]+' src/Common/config.h.in | sort -u)

Both must come back empty.

## The published 26.2.3.2 image was never built from this source

`Dockerfile.hanzo` at the revision the live image carries (`8adc31826d42`) downloads upstream
release tarballs and then runs `mv /usr/bin/clickhouse /usr/bin/hanzo-datastore`, copies
`hanzo-paths.xml` (which is what resolves `path` to `/var/lib/hanzo-datastore/`), a port override
that moves the engine to 8124, and `nginx-header-proxy.conf`. The binary is upstream ClickHouse.

Two consequences worth holding onto. The engine emits `X-ClickHouse-*` because it *is* upstream —
nginx was baked into the image from the beginning, not bolted on later. And there is no
source-level rename on the 26.2 line to port forward: "put the rename on the same 26.2 base" is not
a cherry-pick, it is a new from-source image. `origin/26.2` and `v26.2.3.2-stable` are pristine
upstream, and `main` is not a descendant of either (43,008 commits of divergence).

That build is feasible — 26.2 wants clang 21, the same floor `main` compiles under, and the
from-source `Dockerfile` already takes the Rust nightly as an ARG (26.2 wants
`nightly-2025-07-07`). What it needs decided first is the tag: `imgver` publishes
`max(declared, published)`, which assumes one monotonic lineage and cannot express a 26.2-lineage
image once 26.7 is published.

## Config that lives in git is not config the cluster has

The runner job ceiling is `timeout:` in `infra/k8s/git-runner/config.yaml` in `hanzoai/universe`.
Two independent gaps sit between committing it and a build benefiting from it.

The universe CD Application is deliberately **non-enforcing** — no `syncPolicy.automated` — so a
commit changes nothing on its own; it reports `OutOfSync` and waits. Reconcile the one directory
with `kubectl diff -k infra/k8s/git-runner` then `apply -k`, which moves the cluster toward git
rather than away from it.

Then act_runner reads its config **once at boot**. The ConfigMap is a volume mount, so the file
updates inside every running pod within about a minute — checking the file in a pod therefore
proves nothing. Only a pod that booted after the apply is actually running the new ceiling. Cycle
the StatefulSet and verify against `.status.updatedReplicas`, not pod age.

## Talking to the forge

`git.hanzo.ai` serves only the git wire from outside; its API is not exposed there. Port-forward
`svc/hanzo-git` and use **`/v1/`** — not `/api/v1/`, which 404s. Basic auth with the same
credentials that push works. Useful paths: `/v1/repos/hanzoai/datastore/actions/tasks?limit=N`,
`.../actions/runs/<run>/jobs`, and `/v1/repos/hanzoai/datastore/actions/jobs/<job>/logs` — note the
log endpoint takes a *job* id and only one of a run's two job rows serves logs; the other 404s.

The repo is **not a mirror any more** (`"mirror": false`), whatever `.hanzo/workflows/cicd.yml`
says about mirror-sync. Push to it directly to trigger CI. Because the workflow sets
`cancel-in-progress: true` on `main`, a second push cancels the build the first one started — batch
your commits, and do not push docs while a build you want is running.

## An image-only tag swap starts green and reads nothing

The live StatefulSet sets **no `command` and no `args`**, so the image's own ENTRYPOINT decides
everything. That makes the image, not the manifest, the thing holding the contract — and the
from-source image does not hold the same one the running image does.

    live (Dockerfile.hanzo)        from-source (Dockerfile)
    /usr/bin/hanzo-datastore       /usr/bin/datastore
    /etc/hanzo-datastore-server/   /etc/datastore-server/
    /var/lib/hanzo-datastore/      /var/lib/datastore/   (config.xml:556)

Every one of those is where the cluster has something mounted: the 200Gi PVC at
`/var/lib/hanzo-datastore`, and the whole universe `config.d` set — including `paths.xml`, which is
what actually resolves `path`, and which no image bakes — at `/etc/hanzo-datastore-server/config.d/`.

So a tag swap does not fail. `entrypoint.sh` defaults `DATASTORE_CONFIG` to
`/etc/datastore-server/config.xml`, a directory where none of those overlays are mounted, reads
`path` from the compiled default, and initializes an **empty database on the container's ephemeral
layer**. `/ping` answers 200, both probes pass, and the pod reports 1/1. The parts are still on the
PVC, untouched — the engine simply never looks at them. Reverting the tag brings them back; writes
taken during the window are gone.

Worth being precise about the order of the two doors. Until the contract is aligned the new engine
never touches the existing data directory, so it cannot rewrite a part — the part-format door is
not even open yet. Align the paths and it opens on the first merge, and from there the way back is
a volume snapshot rather than a tag revert. A migration therefore needs *both*, in one reviewed
change: the contract (binary, config dir, path) and a snapshot taken before the engine is first
pointed at real data.
