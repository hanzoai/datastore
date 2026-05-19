# Migration: NuRaft → lux/consensus (Quasar)

Replacement of the embedded NuRaft Raft engine that backs `src/Coordination/`
with `lux/consensus` (Quasar family: `photon → wave → focus → ray` for linear
chains). This document is the file-by-file implementation spec for Blue.

Inputs:

- NuRaft surface: `src/Coordination/` (~14k LOC, ~28 files referencing
  `nuraft::`).
- Lux C API: `~/work/lux/consensus/pkg/c/include/lux_consensus.h` (~170 lines).
- Lux C++ wrapper: `~/work/lux/consensus/pkg/cpp/include/lux/consensus.hpp`
  (~175 lines).
- Lux static lib: `~/work/lux/consensus/pkg/c/lib/libluxconsensus.a`.
- Quasar protocol docs: `~/work/lux/consensus/docs/content/docs/{quasar,wave,
  focus,ray,photon,index}.mdx` and the LP-105 paper at
  `~/work/lux/papers/lp-105-quasar-consensus.tex`.

## 1. Overview

`hanzo-datastore` runs Coordination in-process (Phase 1 landed: standalone
keeper binary dropped; `src/Coordination/` is linked into `dbms` via
`add_object_library(datastore_coordination Coordination)` and gated by the
`USE_NURAFT` macro at boot in `Server.cpp:2468-2620`). This migration replaces
the Raft engine that drives commit while preserving the
`KeeperStateMachine`/`KeeperStorage` ZooKeeper-API layer above it. The end
state is `contrib/NuRaft` deletion (Phase C in `LLM.md`) once feature parity
on a 3-node cluster is demonstrated.

## 2. Concept Mapping

The Lux linear-chain pipeline is `photon → wave → focus → ray → sink`.
Quasar adds dual BLS+Ringtail certificates on top of `wave` for PQ finality.
For a single-region in-process Keeper replacing Raft, we map onto the linear
pipeline only — DAG/PQ are out of scope for the Coordination layer.

| NuRaft concept | Quasar equivalent | C API call(s) |
|---|---|---|
| `nuraft::raft_server` (driver) | `ray::Driver[T]` (linear chain finality driver) — wraps `lux_chain_t` engine type `LUX_ENGINE_CHAIN` | `lux_chain_new`, `lux_chain_start`, `lux_chain_stop`, `lux_chain_destroy` |
| `srv_config { id, endpoint, learner, priority }` | Validator entry in `Config{node_count, k, alpha, beta}` — Lux has no per-server `endpoint`/`priority`/`learner`; transport is via ZAP, not asio | `lux_chain_new(const lux_config_t*)` |
| `cluster_config` (servers list, log_idx) | `Config` snapshot at a finalized height; cluster membership lives in the validator set, not in `lux_config_t` directly | (gap — see §4) |
| Raft `term` | Quasar `epoch` (BLS DKG epoch, `EpochManager`) — only meaningful with full Quasar mode | (gap — not exposed in C API) |
| Raft `index` (monotonic log idx) | `block.height` (uint64) | `lux_block_t{ .height }` |
| `state_machine::commit(idx, log)` | `lux_callback_decision(block_id, user_data)` fired by `Driver` after `beta` consecutive successes | `lux_consensus_register_decision_callback` |
| `state_machine::pre_commit(idx, log)` | (no native equivalent — Quasar finality is monotone; pre-commit is a NuRaft hook for two-phase application) | (gap — emulate with `processing` status check via `Status::Processing`) |
| `state_machine::rollback(idx, log)` | (no equivalent — Quasar never rejects-then-rolls-back a `Processing` block; it either reaches `Accepted` or stays `Processing` until `Rejected`) | C++ `Chain::get_status` returns `Rejected` |
| `log_store::append(entry)` | `lux_chain_add_block(chain, block)` — block payload is the serialized `KeeperRequestForSession` buffer | `lux_chain_add_block` |
| `log_store::write_at(idx, entry)` | (no equivalent — Quasar is append-only; index conflicts cannot occur once `add_block` succeeds because heights are monotone within a chain) | (gap — see §4 on log_store) |
| `log_store::log_entries(start, end)` | Caller-side cache of submitted blocks; the engine does not expose log-range read | (gap — must be reimplemented at the wrapper layer) |
| `log_store::compact(idx)` | Implicit: blocks below the latest snapshot height can be dropped from the wrapper-side cache | (no C API call; wrapper-managed) |
| `log_store::pack/apply_pack` | Used by NuRaft for snapshot transfer to lagging followers; must be reimplemented as a wrapper that ships the serialized block-cache range over ZAP | (gap) |
| Raft snapshot (`save_logical_snp_obj`/`apply_snapshot`) | `KeeperStorage` snapshot at a finalized `block.height`; engine has no built-in snapshot — `KeeperSnapshotManager` continues to own this | (no engine call; existing `KeeperSnapshotManager` retained verbatim) |
| `state_mgr::save_config/save_state/read_state` | Persisted cluster + epoch state (validator set + BLS keys for the next epoch) | (gap — must be persisted by the wrapper layer; no C API support) |
| `cb_func::Type` callback events (BecomeLeader, BecomeFollower, ...) | `lux_callback_notify(event_str, user_data)` — string-keyed; events are decision-flow notifications, NOT leader-state notifications because Quasar is leaderless | `lux_consensus_register_notify_callback` |
| `is_leader()` / `is_leader_alive()` / `get_leader()` | (no concept — Quasar has no leader; every validator can submit blocks; `cluster_config->priority` and leader-yielding RPCs are meaningless) | (gap — see §4) |
| `append_entries(entries)` returning `cmd_result<buffer>` | `lux_chain_add_block` returns `lux_error_t` synchronously; the `Accepted` decision is delivered asynchronously via decision callback | API shape change: futures must be wired in the wrapper |
| `raft_params{ heart_beat_interval_ms, election_timeout_*_ms, leadership_expiry_ms, snapshot_distance, ... }` | `Config{ k, alpha, beta }` + (no equivalent for heart-beat/election since there is no leader). Beta presets: `single_validator{1,1,1,1}`, `local_network{5,3,3,4}`, `testnet{20,10,14,20}`, `mainnet{100,20,15,20}` | `lux_chain_new(&config)` with mapped parameters |
| `nuraft::buffer` (refcounted byte container) | `std::vector<uint8_t> Block::payload` (C++ wrapper) or `void* data, size_t data_size` (C struct) | None — buffer adapters live in `WriteBufferFromNuraftBuffer.{h,cpp}` and `ReadBufferFromNuraftBuffer.h` |

### Quasar protocol layers (reference for §3 mapping decisions)

- **photon**: K-of-N committee selection. Replaces Raft's per-RPC leader-only routing — every node samples K peers per round.
- **wave**: Threshold voting + FPC. Replaces a Raft heartbeat round; α-quorum on the sampled K decides `Prefer`.
- **focus**: β consecutive successes → confidence. Replaces Raft's monotone log-index commit. Sets `Status::Accepted` after β successes.
- **ray**: Linear chain finality driver. Wraps `wave`+`focus` and emits the decision callback. **This is the layer that fills the `nuraft::raft_server` slot.**

## 3. File-by-File Change List

LOC counts are rough — based on `nuraft::` reference density and surrounding
context. "Touch" means *modify*; "delete" means *remove from build*; "shim"
means *replace body, keep header for callers*.

Source: `wc -l` and `grep -c "nuraft::"` runs at investigation time.

| File | Today | Strategy | LOC touched |
|---|---|---|---|
| `src/Coordination/KeeperServer.{h,cpp}` (1347 + 162 = 1509) | Owns `nuraft::raft_server`, configures `raft_params`, manages asio listeners + SSL, exposes `isLeader/isFollower/isObserver/isLeaderAlive`, `applyConfigUpdate`, `requestLeader`, `yieldLeadership`, recovery mode, `putRequestBatch` (returns `RaftAppendResult`) | Rewrite as thin wrapper around `lux::consensus::Chain`. Drop asio + SSL (transport moves to ZAP — already running on `:9999`). Drop leader/follower/observer concepts entirely; `isLeader()` returns `true` always (every node can submit). Recovery mode becomes "rebuild from `KeeperSnapshotManager` latest snapshot + replay block cache". `RaftAppendResult` becomes a `std::future<bool>` resolved on decision callback. `KeeperRaftServer` inner class deleted. | ~1100 |
| `src/Coordination/KeeperStateMachine.{h,cpp}` (272 + 1219 = 1491) | Inherits `nuraft::state_machine`; implements `pre_commit`, `commit`, `rollback`, `apply_snapshot`, `create_snapshot`, `save_logical_snp_obj`, `read_logical_snp_obj`, `commit_config`, `last_commit_index`, `last_snapshot` | Drop the `nuraft::state_machine` base class. Keep `IKeeperStateMachine` and `KeeperStateMachine<Storage>` as interface to `KeeperStorage`; replace the override surface with one method `applyDecidedBlock(uint64_t height, std::span<const uint8_t> payload)` invoked from the decision callback registered with `lux_chain_t`. Snapshot interfaces (`save_logical_snp_obj`, `read_logical_snp_obj`, `apply_snapshot`) become wrapper-side: `KeeperSnapshotManager` already owns the serialization, so just delete the NuRaft-flavored wrappers and call `KeeperSnapshotManager::serializeSnapshotToBuffer` / `deserializeSnapshotFromBuffer` directly from `KeeperServer`. `pre_commit`/`rollback` deleted. `parseRequest` keeps its body but takes `std::span<const uint8_t>` instead of `nuraft::buffer&`. | ~700 |
| `src/Coordination/KeeperStateManager.{h,cpp}` (141 + 607 = 748) | Inherits `nuraft::state_mgr`; implements `load_config/save_config`, `save_state/read_state`, `load_log_store`, `system_exit`. Owns `KeeperLogStore`, `KeeperConfigurationWrapper`, parses XML servers config | Drop `nuraft::state_mgr` base class. Keep XML config parsing (server list still needed for the wrapper layer to know peer endpoints for ZAP). `cluster_config` ↔ `lux_config_t` bridge: at startup, count XML servers → `node_count`, derive `{k, alpha, beta}` via `Config::custom(node_count)`. Persist `srv_state`-equivalent (epoch, last decided height) to a small KeyValueStore on the same disk Keeper uses today. Drop `load_log_store` — the log store is gone (see next two rows). | ~450 |
| `src/Coordination/KeeperLogStore.{h,cpp}` (89 + 164 = 253) | Inherits `nuraft::log_store`; wraps `Changelog`. Implements 16 NuRaft virtuals: `start_index`, `next_slot`, `last_entry`, `append`, `write_at`, `log_entries(_ext)`, `entry_at`, `is_conf`, `term_at`, `pack/apply_pack`, `compact`, `flush`, `last_durable_index`, `end_of_append_batch`, `getLatestConfigChange` | **Delete entirely.** Quasar has no log-store concept. The role split: (a) durable replay log → `Changelog` is repurposed as a write-ahead journal of `applyDecidedBlock` payloads, retained for crash-recovery before the next snapshot; (b) `pack/apply_pack` (NuRaft uses these for inter-node log catch-up) → reimplement at the ZAP-bridge layer as block-range RPC over `:9999` between Keeper peers. | -253 (delete) |
| `src/Coordination/Changelog.{h,cpp}` (497 + 2765 = 3262) | The on-disk changelog format: rotation, ZSTD compression, V0/V1/V2 versions, prefetch caches, `nuraft::log_entry` records | **Keep with surgery.** This is the highest-LOC file but most of it is disk format / cache management that survives the migration. Strip every `nuraft::log_entry`, `nuraft::buffer`, and `nuraft::ptr<>` from headers and impl; `LogEntryPtr` and `BufferPtr` become local aliases for `std::shared_ptr<DecidedBlockEntry>` and `std::shared_ptr<std::vector<uint8_t>>`. The 16 NuRaft-typed signatures of `LogEntryStorage` / `Changelog` shrink because `is_conf`/`term_at`/`getLatestConfigChange` are no longer needed (membership changes are not log entries in Quasar). Disk format version bump → V3 (drop `term`, drop `value_type`). | ~600 (signatures + buffer types; bulk of disk format untouched) |
| `src/Coordination/InMemoryLogStore.{h,cpp}` (50 + 200 = 250) | Test-only `nuraft::log_store` impl backed by `std::map<uint64_t, log_entry>` | **Delete entirely.** Tests that need an in-memory journal use the new `Changelog` with a `MemoryDisk`. | -250 (delete) |
| `src/Coordination/RaftServerConfig.{h,cpp}` (91 + 102 = 193) | `RaftServerConfig` POD + parsing + `nuraft::srv_config` round-trip + `ClusterUpdateAction` variant (Add/Remove/UpdatePriority/TransferLeadership) | **Keep with surgery.** `RaftServerConfig` POD survives (XML config still has `<server id endpoint priority/>`). Strip the `nuraft::srv_config` round-trip operators. Drop `UpdateRaftServerPriority` and `TransferLeadership` from the variant — both are leader-aware concepts that have no Quasar meaning. `ClusterUpdateAction` shrinks to `{AddRaftServer, RemoveRaftServer}`. | ~80 |
| `src/Coordination/KeeperReconfiguration.{h,cpp}` (12 + 99 = 111) | Builds `ClusterConfigPtr` (=`nuraft::cluster_config`) and `KeeperRequestForSession` for reconfig commands | Replace `ClusterConfigPtr` with a new `ClusterMembership` POD (vector of validator IDs, version). Reconfig still flows through the state machine as a special request, but the applied effect is `lux_chain_destroy + lux_chain_new` with the new `node_count`. | ~80 |
| `src/Coordination/KeeperSnapshotManager.{h,cpp}` (215 + 993 = 1208) | Owns serialize/deserialize of `KeeperStorage` → ZSTD/LZ4 buffer; uses `nuraft::snapshot` and `nuraft::buffer` for metadata + transport | Replace `nuraft::snapshot` with a local `KeeperSnapshotMeta { uint64_t up_to_height; ClusterMembership members; }`. Replace `nuraft::buffer` payloads with `std::vector<uint8_t>`. `ClusterConfigPtr` field stays but typed as `ClusterMembership`. The serialization format on disk must stay backward-compatible to read NuRaft-era snapshots — bump `SnapshotVersion::V7` and write `up_to_height` in place of `last_log_idx`. | ~250 |
| `src/Coordination/KeeperSnapshotManagerS3.{h,cpp}` (72 + 351 = 423) | S3 upload of snapshots; uses `nuraft::buffer` | Strip `nuraft::buffer` for `std::vector<uint8_t>`. Otherwise unchanged. | ~30 |
| `src/Coordination/KeeperDispatcher.{h,cpp}` (286 + 1552 = 1838) | The hot path: takes ZooKeeper requests from session threads, batches them, calls `KeeperServer::putRequestBatch`, awaits the `RaftAppendResult` (a `nuraft::cmd_result<nuraft::ptr<nuraft::buffer>>`), routes responses back. Heavy use of `nuraft::async_result` + `nuraft::buffer`. | Replace the `RaftAppendResult` await loop (lines 270-360 area) with a `std::future<DecisionResult>` await wired to the decision callback. Replace `forceWaitAndProcessResult` (line 888) signature: input is now `std::future<...>`, output unchanged. The 8 `nuraft::` references at lines 2, 279-280, 299, 348, 733-734, 888, 895-897 all live in this hot path; touching them is mechanical. | ~250 |
| `src/Coordination/WriteBufferFromNuraftBuffer.{h,cpp}` (4 refs) | `WriteBuffer` adapter writing into a `nuraft::buffer` | Rename `WriteBufferFromVector` (already exists in upstream — collapse) or rename to `WriteBufferFromBytes` and back it with `std::vector<uint8_t>`. | ~40 |
| `src/Coordination/ReadBufferFromNuraftBuffer.h` (2 refs) | `ReadBuffer` adapter reading from a `nuraft::buffer` | Same — rename to `ReadBufferFromBytes`. | ~20 |
| `src/Coordination/SummingStateMachine.{h,cpp}` (16 + 23 = 39) | Test-only `nuraft::state_machine` for changelog/snapshot tests | **Delete entirely.** Replaced by a minimal in-test stub against the new `applyDecidedBlock` interface. | -39 (delete) |
| `src/Coordination/LoggerWrapper.h` (1 ref) | Adapts ClickHouse `LoggerPtr` to `nuraft::logger` | **Delete.** Lux logging via `LUX_LOG_*` macros routed through ClickHouse `Poco::Logger` directly. | -50 (delete) |
| `src/Coordination/FourLetterCommand.{h,cpp}` | `mntr`, `srvr`, `stat`, `conf` 4LW commands; expose Raft state | Strip Raft-leader fields from `srvr`/`mntr` output; add Quasar-equivalent fields (`epoch`, `last_decided_height`, `validator_count`, `accepted_blocks`, `rejected_blocks` from `lux_consensus_get_stats`). 4 `nuraft::` references in `FourLetterCommand.cpp`. | ~80 |
| `src/Coordination/KeeperContext.{h,cpp}` (182 + 719 = 901) | Owns `lastCommittedIndex`, `LocalLogsPreprocessed` flag, settings | `lastCommittedIndex` is renamed `lastDecidedHeight` (semantically same — uint64). No `nuraft::` references; minor rename pass. | ~30 |
| `src/Coordination/CMakeLists.txt` (1 line — `add_headers_and_sources(...)`) | Lists all *.cpp/*.h | Add `lux_consensus_wrapper.cpp` (new shim, ~400 LOC), drop `KeeperLogStore.cpp`, `InMemoryLogStore.cpp`, `SummingStateMachine.cpp`. | ~10 |
| `src/CMakeLists.txt:359-360, 472-474` | `if (TARGET ch_contrib::nuraft)` gates + `target_link_libraries(dbms PUBLIC ch_contrib::nuraft)` | Replace with `if (TARGET ch_contrib::lux_consensus)` and link `libluxconsensus.a` + `pthread`. The `USE_NURAFT` macro becomes `USE_LUX_CONSENSUS`; rename in `Server.cpp:2468` and any other call sites. | ~10 |
| `contrib/CMakeLists.txt:165` (`add_contrib (nuraft-cmake NuRaft)`) | NuRaft contrib registration | Phase A: keep, plus add `add_contrib (lux-consensus-cmake LuxConsensus)`. Phase C: delete. | +5/-1 |
| `contrib/lux-consensus-cmake/CMakeLists.txt` (new) | n/a | Add `IMPORTED STATIC` lib pointing at `~/work/lux/consensus/pkg/c/lib/libluxconsensus.a`, expose `ch_contrib::lux_consensus` target. ~30 LOC. | +30 (new) |
| `programs/server/Server.cpp:2468` (`#if USE_NURAFT` gate around the embedded keeper boot block, lines 2468-2620 per Phase 1 LLM.md) | Boots in-process Keeper | Rename `USE_NURAFT` → `USE_LUX_CONSENSUS`. No structural change — `getKeeperDispatcher()` is unaffected. | ~5 |
| `src/Coordination/tests/gtest_coordination.cpp` (953 LOC, 27 `nuraft` refs incl. 19 `nuraft::`) | Most of these tests construct fake `nuraft::log_entry` / `nuraft::buffer` for the state machine | Rewrite test fixtures to feed `std::vector<uint8_t>` payloads through `applyDecidedBlock`. Logic intact, scaffolding swapped. Estimated test-by-test: ~50% rewrite. | ~500 |
| `src/Coordination/tests/gtest_coordination_changelog.cpp` (1588 LOC, 2 `nuraft` refs only) | Tests `Changelog` directly — most tests don't reach into NuRaft types | Update only the `LogEntryPtr` / `BufferPtr` type aliases (now point at the new POD). Most tests untouched. | ~50 |
| `src/Coordination/tests/gtest_coordination_snapshot.cpp` (580 LOC, 1 `nuraft` ref) | Tests `KeeperSnapshotManager` | Update one place where `nuraft::buffer` is faked. | ~20 |
| `src/Coordination/tests/gtest_coordination_storage.cpp` (1541 LOC, 0 `nuraft` refs) | Tests `KeeperStorage` (nodes, ACLs, watches) | **No changes.** Storage is below the consensus layer. | 0 |
| `src/Coordination/tests/gtest_coordination_common.{h,cpp}` (4 `nuraft` refs) | Test helpers — fake state machine, fake log entries | Update to construct the new POD types. | ~30 |
| **New: `src/Coordination/lux_consensus_wrapper.{h,cpp}`** | n/a | A C++ class `LuxChainWrapper` that wraps `lux_chain_t*`, owns the decision callback, exposes a `std::future<bool> append(uint64_t height, std::vector<uint8_t> payload)` API, persists epoch/state to disk, and holds the validator-set membership transitions. Roughly ~400 LOC including header. **This is the new ownership surface that replaces NuRaft semantics.** | +400 (new) |

**Estimated total LOC touched (modify) + LOC deleted + LOC added (new):** ~4400 modify, ~590 delete, ~430 new ≈ **~5400 LOC of code to write/touch**. The largest single block is `KeeperServer.cpp` (~1100) which is mostly mechanical transport-layer removal once the wrapper is in place.

## 4. Risk Register

Sorted by severity (highest first). The first three are decision-blockers; the remainder are implementation hazards.

### R1. The Lux C SDK is "data structures only, not real consensus" (CRITICAL)

`~/work/lux/consensus/CLAUDE.md` states verbatim: "**C** (`pkg/c/`): Data structures only, not real consensus." The 695-line `consensus_engine.c` confirms this — it is a single-process hash-table over blocks with simple `confidence_count >= beta` decision logic. There is no networking, no cross-node sampling, no actual `wave` round, no `photon` committee selection, no BLS aggregation, no Ringtail.

Implication: **the C API as it stands cannot replace NuRaft.** NuRaft does cross-node log replication; the C engine does not. Linking `libluxconsensus.a` and calling `lux_chain_add_block` on each Keeper node would result in three independent, non-replicating engines.

Resolution path: Blue must escalate to lux/consensus to either (a) ship a real C/C++ binding around the Go `engine/chain` (`Driver` etc.) — likely via cgo + a thin shim — or (b) link the Go consensus engine in directly via cgo on the datastore side. Option (a) is cleaner. **Without one of these, the migration cannot proceed past Phase A.**

### R2. ZooKeeper API guarantees vs. async sample-based consensus (HIGH)

Datastore's ZooKeeper API contract (which all `Replicated*` engines depend on) provides **linearizable writes** and **sequential consistency for reads from a single session**. NuRaft delivers this via synchronous log replication: a write is `commit`ted only after a quorum durably appended it.

Quasar's `wave→focus→ray` is α-quorum + β-confidence sampling. A block reaches `Status::Accepted` after β consecutive successful sampling rounds. This is **probabilistically safe** under the `papers/lp-105-quasar-consensus.tex` Theorem 7.5 (soundness), but the guarantee is not "every node sees the same prefix" — it is "no two honest nodes accept conflicting blocks with overwhelming probability under the standard adversary model".

For Coordination this means:

- A submitted znode write may take longer to "commit" (β rounds, β=20 mainnet, β=4 local) than NuRaft's one-roundtrip-to-quorum. With local-network preset (`{node_count=5, k=3, alpha=3, beta=4}`) and ~5ms ZAP RTT, expect 20-40ms decision latency vs. NuRaft's <5ms. Bench before claiming parity.
- Watchers fire on `commit`; with the async decision callback, ordering between watch-fire and write-ack across a single session is preserved iff the wrapper enforces it (it must — `KeeperDispatcher` already holds `process_and_responses_lock`).
- Read-after-write within a session: ZooKeeper requires this for the same client. NuRaft enforces via leader-routed reads (`quorum_reads=true`) or sequential commit. Quasar has no leader → all reads must be served from a height ≥ the height of the most recent write the same session issued. Wrapper must track per-session `last_decided_height` and gate reads.

This risk is **manageable** but requires the wrapper to do work NuRaft did for free. If we get it wrong, `Replicated*` table replication breaks silently (split-brain on znode writes).

### R3. No leader, no `cluster_config`, no `srv_state` (HIGH)

NuRaft callers in datastore lean on leader-awareness:

- `KeeperServer::isLeader()` is consulted in `KeeperDispatcher.cpp` to decide whether to forward a write to the leader (`auto_forwarding_=true` in NuRaft) or process it locally.
- `KeeperReconfiguration` issues `TransferLeadership` and `UpdatePriority` actions over the wire as ZooKeeper requests — these are first-class API operations.
- 4LW `srvr` command exposes `Mode: leader|follower|observer` to clients; ops tooling parses this.

In Quasar there is no leader. Consequences:

- `auto_forwarding_` becomes a no-op — every node submits its own writes to the local `lux_chain_t`. Conflict resolution moves into Quasar (FPC selector under `wave/fpc`).
- `applyConfigUpdate(TransferLeadership{...})` and `applyConfigUpdate(UpdatePriority{...})` must return an error; they have no meaning. This is a **client-visible API change** for any tooling that issued these — `clickhouse-keeper-client` would need to drop these commands.
- 4LW output changes: `Mode:` → reports `validator` always; new fields for epoch/decided-height. Operators using the old strings will see broken dashboards.

### R4. No `pre_commit` / `rollback` symmetric pair (MEDIUM)

`KeeperStateMachine::pre_commit` is used by datastore to validate the request (compute digest, check quotas) **before** the commit fires, and `rollback` undoes that work if the entry is dropped (e.g., leader change with uncommitted log suffix). Quasar never produces dropped suffixes — once `add_block` returns success, the block either reaches `Accepted` or stays `Processing` indefinitely (until rejected by FPC, which marks it `Rejected` directly without a "rollback" step).

The wrapper must collapse pre_commit + commit into a single decided-block apply. The digest-checking that lived in `pre_commit` moves into the verify callback (`lux_callback_verify`) which fires **before** the block is admitted into the chain. `rollback` becomes a no-op or outright deleted method; any caller that depends on rollback semantics (search `KeeperDispatcher.cpp` and `KeeperStateMachine.cpp` for `rollback`) must be reviewed.

### R5. Snapshot install on a lagging follower (MEDIUM)

NuRaft handles "follower fell behind, install snapshot" via the `save_logical_snp_obj` / `read_logical_snp_obj` / `apply_snapshot` triplet. The C API has nothing for this — `lux_chain_t` doesn't even know there are other nodes. The wrapper must implement snapshot transfer over ZAP itself. This is non-trivial: chunked transfer, version negotiation, atomic apply. ~200 LOC of new wrapper code that's not in §3 estimates. Add to the wrapper's responsibility set.

### R6. Test churn (MEDIUM)

`gtest_coordination.cpp` (953 LOC, 27 nuraft refs) is the integration test for the state machine + log store + dispatcher. ~50% rewrite. CI must stay green through Phase A (both engines available); the gtest binary should run all tests against both NuRaft and Lux paths via a parameterized fixture. Adds ~1 day of test-engineer time per affected test file.

### R7. ABI / API churn for downstream tooling (LOW)

`clickhouse-keeper-client` and `clickhouse-keeper-converter` (under `programs/keeper-client/`, `programs/keeper-converter/`) consume the `KeeperServer` and `KeeperSnapshotManager` types. Any signature change ripples. Phase 1 already dropped the standalone keeper binary, but the converter still ships in some packages. Verify before Phase C deletion.

## 5. Test Surface

| Test file | Action | Why |
|---|---|---|
| `src/Coordination/tests/gtest_coordination_storage.cpp` | No changes | Tests `KeeperStorage` (znodes, ACLs, watches) — sits *above* the consensus layer. 0 nuraft refs. |
| `src/Coordination/tests/gtest_coordination_changelog.cpp` | Light update (~50 LOC) | Tests on-disk format. Once `LogEntryPtr` aliases swap, tests run unchanged. 2 nuraft refs. |
| `src/Coordination/tests/gtest_coordination_snapshot.cpp` | Light update (~20 LOC) | Tests `KeeperSnapshotManager`. 1 nuraft ref. |
| `src/Coordination/tests/gtest_coordination_common.{h,cpp}` | Update test fixtures (~30 LOC) | Mock state machine has 4 nuraft refs. |
| `src/Coordination/tests/gtest_coordination.cpp` | Rewrite (~500 LOC) | Heavy on `nuraft::log_entry`, `nuraft::buffer` faking. 27 nuraft refs incl. 19 `nuraft::`. |
| **New: `src/Coordination/tests/gtest_lux_wrapper.cpp`** | New file (~300 LOC) | Unit tests for `LuxChainWrapper` decision callback ordering, future resolution, snapshot install path, async-vs-sync semantics under R2. |
| `tests/integration/test_keeper_*` (Python integration tests, in `tests/integration/`) | Run as-is on Phase A; expect some flakes in tests that assume Raft leader semantics (search for `is_leader`, `leader_election`, `transfer_leadership`) | These exercise the full server. Tests that asserted leader-id stability or transfer-leadership semantics will fail; mark them xfail under `lux` engine in Phase A, delete in Phase C. ~5-10 tests affected based on grep of `tests/integration/test_keeper*`. |
| Praktika / CI selection: `python -m ci.praktika run "integration" --test test_keeper` | Run on every PR against both engines | Use a build flag matrix `USE_LUX_CONSENSUS=ON|OFF` so CI exercises both code paths through Phase B. |

## 6. Phasing

### Phase A — Shim layer, both engines available behind a runtime flag

Goal: code lands, neither path regresses, ops can flip a config switch.

1. Add `contrib/lux-consensus-cmake/` exposing `ch_contrib::lux_consensus`.
2. Implement `src/Coordination/lux_consensus_wrapper.{h,cpp}` with the full `LuxChainWrapper` interface against the C API (mock the cross-node parts with a single-validator config; this is enough to compile and unit-test).
3. Introduce a runtime flag `keeper_server.consensus_engine = nuraft|lux` in `keeper_embedded.xml`. Default `nuraft`.
4. In `KeeperServer.cpp`, branch at construction: instantiate the NuRaft path or the Lux wrapper path based on the flag.
5. Both `IKeeperStateMachine` and a new `IKeeperStateMachineLux` exist; `KeeperStateMachine<Storage>` becomes a template that satisfies both interfaces (or two parallel classes — pick whichever yields less duplication).
6. Build flag `USE_LUX_CONSENSUS` + `USE_NURAFT` both ON.
7. `gtest_coordination*` parameterized over both engines.
8. Integration-test pass: full keeper test suite green on both engines.

**Exit criteria:** datastore image runs on a 3-node cluster with `consensus_engine=nuraft` (today's behavior, unchanged) and the unit tests pass on `consensus_engine=lux` against a single-node config. The `lux` path is **not yet production-viable** because of R1 — that's resolved before Phase B.

### Phase B — Lux as default with NuRaft fallback

Pre-requisite: R1 (real cross-node consensus in the C/C++ binding) resolved upstream and exposed via either an extended C API or via cgo into Go. Without this, do not enter Phase B.

1. Cross-node ZAP RPC for block submission and snapshot transfer wired into the wrapper.
2. Flip `consensus_engine` default to `lux` in `keeper_embedded.xml`.
3. Run a 7-day soak on a staging Replicated cluster with workload mirrored from production.
4. Observe: write latency p50/p99, watcher delivery latency, replication lag for `Replicated*` tables, no split-brain znode events, snapshot install successfully on a lagging follower (forced via downtime).
5. CI matrix unchanged — both paths still build.
6. `clickhouse-keeper-client`'s `transfer_leadership` and `update_priority` commands return a structured "not supported on lux engine" error.

**Exit criteria:** mainnet-equivalent staging clusters running on `lux` for 7 days with no SEV; rollback path (`consensus_engine=nuraft`) verified via a forced downgrade drill.

### Phase C — NuRaft + contrib/NuRaft removed

1. `git rm -r contrib/NuRaft contrib/nuraft-cmake`.
2. `git rm src/Coordination/{InMemoryLogStore.{h,cpp},KeeperLogStore.{h,cpp},LoggerWrapper.h,SummingStateMachine.{h,cpp},WriteBufferFromNuraftBuffer.{h,cpp},ReadBufferFromNuraftBuffer.h}`.
3. Drop the `consensus_engine` flag (Lux is the only engine).
4. Drop `USE_NURAFT` macro and all `#if USE_NURAFT` branches across the codebase.
5. Drop `clickhouse-keeper-converter` from packaging (the converter targets ZooKeeper snapshot format → Keeper snapshot format, which is unchanged; but since the keeper converter is itself a NuRaft consumer in some code paths, audit before deletion).
6. Drop xfail markers on the integration tests that asserted leader semantics; delete the tests outright.
7. Update `LLM.md` — remove the Phase C deferred-deletion list entry and add a "completed Phase C: lux/consensus" line.

**Exit criteria:** `git grep -r "nuraft\|NuRaft\|libnuraft" src/ programs/ contrib/` returns zero hits.

---

## Appendices

### A. NuRaft references — count by file (verification)

```
KeeperServer.cpp:75   KeeperStateMachine.cpp:25   SummingStateMachine.cpp:23
InMemoryLogStore.cpp:21   SummingStateMachine.h:16   KeeperStateMachine.h:15
Changelog.cpp:15   KeeperStateManager.cpp:14   KeeperServer.h:11
KeeperLogStore.h:11   KeeperStateManager.h:10   KeeperLogStore.cpp:10
KeeperSnapshotManager.h:9   KeeperSnapshotManager.cpp:9   InMemoryLogStore.h:9
KeeperDispatcher.cpp:8   Changelog.h:8   WriteBufferFromNuraftBuffer.cpp:4
RaftServerConfig.h:3   WriteBufferFromNuraftBuffer.h:2   ReadBufferFromNuraftBuffer.h:2
RaftServerConfig.cpp:2   LoggerWrapper.h:1   KeeperDispatcher.h:1
```

Total non-test files referencing `nuraft::`: 28. Total `nuraft::` references in non-test sources: ~199.

Test files: `gtest_coordination.cpp` 27 refs, `gtest_coordination_common.cpp` 4, `gtest_coordination_changelog.cpp` 2, `gtest_coordination_snapshot.cpp` 1.

### B. Specific gaps Blue will hit, in implementation order

The following are **certain** API gaps in the current C SDK (`pkg/c/include/lux_consensus.h`). Each must be either added upstream in lux/consensus or worked around in the wrapper.

| Gap | Why it blocks | Suggested fix |
|---|---|---|
| No cross-node networking | R1 — C engine is single-process | Upstream: ship cgo binding to `engine/chain.Driver` |
| No snapshot install API | R5 — can't catch up a lagging node | Wrapper-side: ZAP RPC for snapshot chunks |
| No validator-set mutation API | R3 — reconfiguration must restart the chain | Upstream: add `lux_chain_reconfigure(chain, new_config)` |
| No durable epoch persistence hook | Wrapper must persist `srv_state` equivalent itself | Upstream: optional, fine to do wrapper-side |
| No `last_decided_height` getter | Wrapper must track via decision callback | Upstream: add `lux_consensus_get_last_height()` |
| No log-range read | NuRaft `log_entries(start, end)` consumed by snapshot install | Wrapper-side cache on submitted blocks |
| No way to drain pending blocks on shutdown | Crash-clean shutdown semantics | Upstream: add `lux_chain_drain(chain, timeout_ms)` |

### C. References

- NuRaft API used: `~/work/hanzo/datastore/contrib/NuRaft/include/libnuraft/*.hxx`
- Lux C header: `~/work/lux/consensus/pkg/c/include/lux_consensus.h`
- Lux C++ wrapper: `~/work/lux/consensus/pkg/cpp/include/lux/consensus.hpp`
- Lux C engine source: `~/work/lux/consensus/pkg/c/src/consensus_engine.c` (~695 lines, single-process)
- Lux C SDK status (data-only): `~/work/lux/consensus/CLAUDE.md` SDK Status section
- Quasar protocol: `~/work/lux/consensus/docs/content/docs/{quasar,wave,focus,ray,photon}.mdx`
- LP-105 paper (soundness Thm 7.5, liveness 7.6, PQ-safety 7.7): `~/work/lux/papers/lp-105-quasar-consensus.tex`
- Phase A (single-binary) status: `~/work/hanzo/datastore/LLM.md` Phase 1 section
- Phase B/C deferred lists: `~/work/hanzo/datastore/CLAUDE.md` Phase B/C sections
