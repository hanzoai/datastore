// keeper_quasar_engine_test.cpp — exercises the QuasarKeeperConsensus engine
// against the REAL KeeperStateMachine<KeeperMemoryStorage> + KeeperStorage, and
// asserts the full commit contract the dispatcher relies on:
//   * append() orders + commits a batch, returns accepted + last_log_idx
//   * the real KeeperStorage reflects every committed write
//   * the dispatcher commit_callback fires once per entry, in log order
//   * KeeperContext's committed index advances to the batch length
//   * a second batch continues the same monotonic log
//
// Build & run on a configured datastore build:
//   cmake -DENABLE_EXAMPLES=1 -DLUXCONSENSUS_DIR=<pkg/c> .
//   ninja keeper_quasar_engine_test && ./src/Coordination/examples/keeper_quasar_engine_test
// Expected tail (exit 0):
//   == QuasarKeeperConsensus drives the real Keeper commit path — zero Raft ==

#include <Coordination/QuasarKeeperConsensus.h>
#include <Coordination/KeeperStateMachine.h>
#include <Coordination/KeeperContext.h>
#include <Coordination/CoordinationSettings.h>
#include <Coordination/KeeperStorage.h>
#include <Coordination/KeeperCommon.h>
#include <Common/ZooKeeper/ZooKeeperCommon.h>
#include <Disks/DiskLocal.h>

#include <cstdio>
#include <filesystem>
#include <memory>
#include <string>
#include <vector>

using namespace DB;

namespace
{

int g_failures = 0;
void must(bool cond, const std::string & what)
{
    if (!cond) { std::printf("  ASSERT FAILED: %s\n", what.c_str()); ++g_failures; }
}

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

KeeperRequestForSession forSession(int64_t session, const Coordination::ZooKeeperRequestPtr & request)
{
    KeeperRequestForSession rfs;
    rfs.session_id = session;
    rfs.request = request;
    return rfs;
}

}

int main()
{
    std::printf("== QuasarKeeperConsensus engine over the REAL KeeperStateMachine ==\n");

    auto settings = std::make_shared<CoordinationSettings>();
    auto keeper_context = std::make_shared<KeeperContext>(/*standalone_keeper*/ true, settings);

    namespace fs = std::filesystem;
    const std::string base = "/tmp/keeper_quasar_engine_test";
    fs::remove_all(base);
    fs::create_directories(base + "/log");
    fs::create_directories(base + "/snapshots");
    fs::create_directories(base + "/state");
    keeper_context->setLogDisk(std::make_shared<DiskLocal>("LogDisk", base + "/log"));
    keeper_context->setSnapshotDisk(std::make_shared<DiskLocal>("SnapshotDisk", base + "/snapshots"));
    keeper_context->setStateFileDisk(std::make_shared<DiskLocal>("StateFile", base + "/state"));
    keeper_context->setRocksDBOptions();

    SnapshotsQueue snapshots_queue{1};

    // The dispatcher's commit callback: fired once per committed entry. We record
    // the order to assert exactly-once, in-order delivery.
    std::vector<uint64_t> commit_log;
    IKeeperStateMachine::CommitCallback commit_callback =
        [&](uint64_t log_idx, const KeeperRequestForSession &) { commit_log.push_back(log_idx); };

    auto state_machine = std::make_shared<KeeperStateMachine<KeeperMemoryStorage>>(
        /*response_callback*/ nullptr, snapshots_queue, keeper_context, /*snapshot_manager_s3*/ nullptr,
        commit_callback, /*superdigest*/ "");
    state_machine->init();

    QuasarKeeperConsensus engine(*state_machine, keeper_context, /*node_count*/ 1);
    engine.startup();
    must(engine.isLeader(), "single node is leader");
    must(engine.isLeaderAlive(), "single node has a live leader");
    std::printf("engine up: leader=%d running=%d\n", engine.isLeader(), engine.isRunning());

    // --- batch 1: a realistic ReplicatedMergeTree coordination sequence ---
    const int64_t session = 1;
    KeeperRequestsForSessions batch1 = {
        forSession(session, createReq("/clickhouse", "")),
        forSession(session, createReq("/clickhouse/tables", "")),
        forSession(session, createReq("/clickhouse/tables/events", "")),
        forSession(session, createReq("/clickhouse/tables/events/replicas", "")),
        forSession(session, createReq("/clickhouse/tables/events/replicas/r1", "active")),
        forSession(session, createReq("/clickhouse/tables/events/block_numbers", "0")),
        forSession(session, setReq("/clickhouse/tables/events/block_numbers", "1")),
    };

    auto out1 = engine.append(batch1);
    must(out1.accepted, "batch1 accepted");
    must(out1.last_log_idx == batch1.size(), "batch1 last_log_idx == batch length");
    must(commit_log.size() == batch1.size(), "commit_callback fired once per entry (batch1)");
    bool in_order = true;
    for (size_t i = 0; i < commit_log.size(); ++i)
        if (commit_log[i] != i + 1) in_order = false;
    must(in_order, "commit_callback fired in strict log order");
    must(keeper_context->lastCommittedIndex() == batch1.size(), "KeeperContext committed index advanced to batch1 length");
    must(engine.lastCommittedIndex() == batch1.size(), "engine committed index == batch1 length");

    // --- batch 2: continues the same monotonic log ---
    KeeperRequestsForSessions batch2 = {
        forSession(session, setReq("/clickhouse/tables/events/block_numbers", "2")),
        forSession(session, createReq("/clickhouse/tables/events/leader_election", "r1")),
    };
    auto out2 = engine.append(batch2);
    must(out2.accepted, "batch2 accepted");
    must(out2.last_log_idx == batch1.size() + batch2.size(), "batch2 continues the log");
    must(keeper_context->lastCommittedIndex() == batch1.size() + batch2.size(), "committed index spans both batches");

    // --- the REAL KeeperStorage must reflect the committed log ---
    auto & storage = state_machine->getStorageUnsafe();
    must(storage.container.contains("/clickhouse"), "node /clickhouse present");
    must(storage.container.contains("/clickhouse/tables/events/replicas/r1"), "replica r1 present");
    must(storage.container.contains("/clickhouse/tables/events/leader_election"), "leader_election present");
    must(storage.container.getValue("/clickhouse/tables/events/block_numbers").getData() == "2",
         "block_numbers == '2' (both SETs applied in order)");
    must(storage.container.getValue("/clickhouse/tables/events/replicas/r1").getData() == "active", "r1 data == 'active'");

    std::printf("committed %zu entries across 2 batches; final committed index=%llu; storage OK\n",
                commit_log.size(),
                static_cast<unsigned long long>(keeper_context->lastCommittedIndex()));

    engine.shutdown();
    must(!engine.isRunning(), "engine stopped");

    if (g_failures)
    {
        std::printf("== %d assertion(s) FAILED ==\n", g_failures);
        return 1;
    }
    std::printf("== QuasarKeeperConsensus drives the real Keeper commit path — zero Raft ==\n");
    return 0;
}
