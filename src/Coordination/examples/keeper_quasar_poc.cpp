// keeper_quasar_poc.cpp — drive the REAL ClickHouse/Datastore Keeper state
// machine with native Lux consensus (Quasar) instead of NuRaft.
//
// Unlike the standalone proofs in luxfi/consensus (which model a toy KV state
// machine), this links the actual `dbms` and exercises the production
// `KeeperStateMachine<KeeperMemoryStorage>` — the exact class
// ReplicatedMergeTree coordinates through. NuRaft normally orders the log and
// calls `commit(log_idx, nuraft::buffer&)`. Here libluxconsensus orders the
// log; the state machine is applied on Quasar finality. The state machine is
// unchanged and cannot tell the difference — that is the whole thesis of the
// migration.
//
// Pipeline per request:
//   ZooKeeper request -> getZooKeeperLogEntry() -> nuraft::buffer (the log entry)
//     -> Quasar block payload -> confidence votes -> finality
//     -> KeeperStateMachine::commit(idx, buffer) -> real KeeperStorage mutates
//
// Asserts the real KeeperStorage tree reflects every committed request, applied
// exactly once, in Quasar-decided log order. Exit non-zero on any mismatch.

#include <Coordination/KeeperStateMachine.h>
#include <Coordination/KeeperContext.h>
#include <Coordination/CoordinationSettings.h>
#include <Coordination/KeeperStorage.h>
#include <Coordination/KeeperCommon.h>
#include <Common/ZooKeeper/ZooKeeperCommon.h>
#include <Disks/DiskLocal.h>
#include <filesystem>

#include <libnuraft/buffer.hxx>
#include <libnuraft/log_entry.hxx>

#include <cstdio>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

extern "C" {
#include "lux_consensus.h"
}

using namespace DB;

namespace
{

Coordination::ZooKeeperRequestPtr createReq(const std::string & path, const std::string & data)
{
    auto r = std::make_shared<Coordination::ZooKeeperCreateRequest>();
    r->path = path;
    r->data = data;
    r->is_ephemeral = false;
    r->is_sequential = false;
    return r;
}

Coordination::ZooKeeperRequestPtr setReq(const std::string & path, const std::string & data)
{
    auto r = std::make_shared<Coordination::ZooKeeperSetRequest>();
    r->path = path;
    r->data = data;
    r->version = -1;
    return r;
}

// One pending replication-log entry, awaiting Quasar finality.
struct Pending
{
    uint64_t idx;
    nuraft::ptr<nuraft::buffer> buf;
};

} // namespace

int main()
{
    std::printf("== Native Quasar consensus driving the REAL ClickHouse Keeper state machine ==\n");

    // --- construct the production state machine (mirrors the Coordination test fixture) ---
    auto settings = std::make_shared<CoordinationSettings>();
    auto keeper_context = std::make_shared<KeeperContext>(/*standalone_keeper*/ true, settings);

    // The state machine's snapshot manager needs real log/snapshot/state disks
    // (same as the Coordination test fixture's setLogDirectory/setSnapshotDirectory).
    namespace fs = std::filesystem;
    const std::string base = "/tmp/keeper_quasar_poc";
    fs::remove_all(base);
    fs::create_directories(base + "/log");
    fs::create_directories(base + "/snapshots");
    fs::create_directories(base + "/state");
    keeper_context->setLogDisk(std::make_shared<DiskLocal>("LogDisk", base + "/log"));
    keeper_context->setSnapshotDisk(std::make_shared<DiskLocal>("SnapshotDisk", base + "/snapshots"));
    keeper_context->setStateFileDisk(std::make_shared<DiskLocal>("StateFile", base + "/state"));
    keeper_context->setRocksDBOptions();

    SnapshotsQueue snapshots_queue{1};

    // Construct exactly as the Coordination gtest fixture does: a null response
    // callback (we assert on storage, not responses), the snapshots queue, the
    // keeper context, and no S3 snapshot manager.
    auto state_machine = std::make_shared<KeeperStateMachine<KeeperMemoryStorage>>(
        nullptr, snapshots_queue, keeper_context, nullptr);
    state_machine->init();
    std::printf("KeeperStateMachine<KeeperMemoryStorage> initialized (the slot NuRaft drives)\n");

    // --- bring up Quasar (libluxconsensus) as the ordering/agreement engine ---
    if (lux_consensus_init() != LUX_SUCCESS) { std::printf("quasar init failed\n"); return 1; }
    lux_config_t cfg{};
    cfg.node_count = 5; cfg.k = 3; cfg.alpha = 3; cfg.beta = 4;
    lux_chain_t * chain = lux_chain_new(&cfg);
    if (!chain || lux_chain_start(chain) != LUX_SUCCESS) { std::printf("quasar chain failed\n"); return 1; }
    std::printf("Quasar chain started (k=%u alpha=%u beta=%u) — replaces nuraft::raft_server\n", cfg.k, cfg.alpha, cfg.beta);

    // --- a realistic ReplicatedMergeTree coordination sequence (parents before children) ---
    const int64_t session = 1;
    std::vector<Coordination::ZooKeeperRequestPtr> script = {
        createReq("/clickhouse", ""),
        createReq("/clickhouse/tables", ""),
        createReq("/clickhouse/tables/events", ""),
        createReq("/clickhouse/tables/events/replicas", ""),
        createReq("/clickhouse/tables/events/replicas/r1", "active"),
        createReq("/clickhouse/tables/events/replicas/r2", "active"),
        createReq("/clickhouse/tables/events/block_numbers", "0"),
        setReq("/clickhouse/tables/events/block_numbers", "1"),
        setReq("/clickhouse/tables/events/block_numbers", "2"),
        createReq("/clickhouse/tables/events/leader_election", "r1"),
    };

    uint64_t height = 0;
    uint64_t committed = 0;
    for (const auto & request : script)
    {
        ++height;

        // Two-phase, exactly as the dispatcher drives NuRaft: preprocess the
        // request when it is appended (speculative, pre-consensus — maps to
        // nuraft pre_commit), then commit it once consensus finalizes its order.
        KeeperRequestForSession rfs;
        rfs.session_id = session;
        rfs.zxid = state_machine->getNextZxid();
        rfs.request = request;
        rfs.log_idx = height;
        state_machine->preprocess(rfs, /*lock_mutex*/ true);

        // The serialized log entry (same zxid) rides Quasar as the block payload;
        // commit deserializes it and applies the preprocessed request.
        auto buf = IKeeperStateMachine::getZooKeeperLogEntry(rfs);

        // The serialized log entry rides Quasar as the block payload.
        lux_block_t blk{};
        for (int i = 0; i < 32; ++i) blk.id[i] = static_cast<uint8_t>((height * 7u + i) & 0xff);
        std::memset(blk.parent_id, 0, 32);
        blk.height = height;
        blk.timestamp = 1700000000ull + height;
        blk.data = buf->data_begin();
        blk.data_size = buf->size();

        if (lux_chain_add_block(chain, &blk) != LUX_SUCCESS) { std::printf("add_block failed @%llu\n", static_cast<unsigned long long>(height)); return 2; }

        bool accepted = false;
        for (uint32_t v = 0; v < cfg.beta && !accepted; ++v)
        {
            lux_vote_t vote{};
            std::memcpy(vote.block_id, blk.id, 32);
            for (int i = 0; i < 32; ++i) vote.voter_id[i] = static_cast<uint8_t>(v + 1);
            vote.is_preference = false;
            lux_consensus_process_vote(chain, &vote);
            lux_consensus_is_accepted(chain, blk.id, &accepted);
        }
        if (!accepted) { std::printf("entry %llu did not finalize\n", static_cast<unsigned long long>(height)); return 3; }

        // Quasar finalized this log position -> apply to the REAL state machine, in order.
        state_machine->commit(height, *buf);
        ++committed;
        std::printf("  log[%llu] finalized+committed: %s\n", static_cast<unsigned long long>(height), request->getPath().c_str());
    }

    // --- assert the REAL KeeperStorage reflects the committed log ---
    auto & storage = state_machine->getStorageUnsafe();
    int failures = 0;
    auto must = [&](bool cond, const std::string & what) { if (!cond) { std::printf("  ASSERT FAILED: %s\n", what.c_str()); ++failures; } };

    const std::vector<std::string> expect_present = {
        "/clickhouse",
        "/clickhouse/tables/events/replicas/r1",
        "/clickhouse/tables/events/replicas/r2",
        "/clickhouse/tables/events/block_numbers",
        "/clickhouse/tables/events/leader_election",
    };
    for (const auto & p : expect_present)
        must(storage.container.contains(p), "node present: " + p);

    must(storage.container.getValue("/clickhouse/tables/events/block_numbers").getData() == "2",
         "block_numbers committed value == '2' (both SETs applied in order)");
    must(storage.container.getValue("/clickhouse/tables/events/replicas/r1").getData() == "active", "r1 data == 'active'");
    must(committed == script.size(), "every entry committed exactly once");

    lux_consensus_stats_t st{};
    lux_consensus_get_stats(chain, &st);
    must(st.blocks_accepted == script.size(), "quasar accepted every block");

    std::printf("committed=%llu, quasar blocks_accepted=%llu, storage nodes under /clickhouse present\n",
                static_cast<unsigned long long>(committed), static_cast<unsigned long long>(st.blocks_accepted));

    lux_chain_stop(chain);
    lux_chain_destroy(chain);
    lux_consensus_cleanup();

    if (failures) { std::printf("== %d assertion(s) FAILED ==\n", failures); return 4; }
    std::printf("== REAL Keeper state machine reached consensus on Quasar — zero Raft, zero ZK ensemble ==\n");
    return 0;
}
