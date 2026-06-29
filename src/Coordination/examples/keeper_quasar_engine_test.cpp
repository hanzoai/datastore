// keeper_quasar_engine_test.cpp — drives the REAL KeeperStateMachine through the
// REAL leaderless Lux consensus (consensus2): a 5-validator set, real BLS12-381
// signed votes, and a >2/3-stake quorum certificate per committed entry. This is
// the NuRaft cutover: the ZooKeeper write log reaches genuine quorum-cert finality
// (NOT the forgeable toy counter) and applies to KeeperStorage in consensus order.
//
// Build & run on a configured datastore build:
//   cmake -DENABLE_EXAMPLES=1 -DCONSENSUS2_DIR=<consensus2> -DLUXCPP_ROOT=<luxcpp> .
//   ninja keeper_quasar_engine_test && ./src/Coordination/examples/keeper_quasar_engine_test
// Expected tail (exit 0):
//   == real KeeperStateMachine finalized by a >2/3-stake quorum cert — zero Raft ==

#include <Coordination/QuasarKeeperConsensus.h>
#include <Coordination/KeeperStateMachine.h>
#include <Coordination/KeeperContext.h>
#include <Coordination/CoordinationSettings.h>
#include <Coordination/KeeperStorage.h>
#include <Coordination/KeeperCommon.h>
#include <Common/ZooKeeper/ZooKeeperCommon.h>
#include <Disks/DiskLocal.h>

#include "lux/consensus2/quorum_cert_engine.hpp"
#include "lux/consensus2/wave.hpp"
#include "bls_signature.hpp"

#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <memory>
#include <string>
#include <vector>

using namespace DB;
namespace c2 = lux::consensus2;

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

// A real BLS keypair, deterministic from a tag.
struct Key { std::array<std::uint8_t, 32> sk{}; c2::PubKey pk{}; };
Key makeKey(std::uint8_t tag)
{
    std::array<std::uint8_t, 32> seed{};
    seed[0] = tag;
    for (int i = 1; i < 32; ++i) seed[i] = std::uint8_t(0xA5 ^ (tag + i));
    Key k;
    if (cevm::crypto::bls::keygen(seed.data(), k.sk.data()) != 0) { std::puts("keygen failed"); std::exit(2); }
    if (cevm::crypto::bls::sk_to_pk(k.sk.data(), k.pk.data()) != 0) { std::puts("sk_to_pk failed"); std::exit(2); }
    return k;
}
c2::Signature signVote(const Key & key, const c2::VotePosition & pos)
{
    const std::vector<std::uint8_t> msg = c2::canonical_vote_message(pos);
    c2::Signature s{};
    if (cevm::crypto::bls::sign(key.sk.data(), msg.data(), msg.size(), s.data()) != 0) { std::puts("sign failed"); std::exit(2); }
    return s;
}

}

int main()
{
    std::printf("== KeeperStateMachine over REAL consensus2 (BLS quorum cert, 5 validators) ==\n");

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

    // The dispatcher's commit callback: fired once per committed entry, in order.
    std::vector<uint64_t> commit_log;
    IKeeperStateMachine::CommitCallback commit_callback =
        [&](uint64_t log_idx, const KeeperRequestForSession &) { commit_log.push_back(log_idx); };

    auto state_machine = std::make_shared<KeeperStateMachine<KeeperMemoryStorage>>(
        /*response_callback*/ nullptr, snapshots_queue, keeper_context, /*snapshot_manager_s3*/ nullptr,
        commit_callback, /*superdigest*/ "");
    state_machine->init();

    // 5-validator set, stake 20 each (total 100), α = 4. floor(2/3·100)=66 ⇒ a
    // committed entry needs ≥4 distinct signed votes carrying >66 stake.
    std::vector<Key> keys;
    for (std::uint8_t i = 0; i < 5; ++i) keys.push_back(makeKey(std::uint8_t(0x60 + i)));
    std::vector<c2::Validator> set;
    for (const auto & k : keys) set.push_back({k.pk, 20});

    QuasarKeeperConsensus engine(*state_machine, set, /*alpha=*/4,
                                 c2::WaveConfig{/*k=*/5, /*alpha=*/0.8, /*beta=*/4}, /*epoch=*/1);
    must(engine.totalStake() == 100, "validator stake == 100");

    const int64_t session = 1;

    // Drive one ZooKeeper request to genuine quorum-cert finality: 4 virtuous polls
    // (wave Accept) + `n_votes` real signed votes, then commit.
    auto coordinate = [&](const Coordination::ZooKeeperRequestPtr & req, int n_votes) {
        const c2::VotePosition pos = engine.submit(forSession(session, req));
        for (int r = 0; r < 4; ++r) engine.recordPoll(pos.block_id, /*yes=*/5, /*total=*/5);
        for (int i = 0; i < n_votes; ++i) engine.recordVote(pos.block_id, keys[i].pk, signVote(keys[i], pos));
        return engine.tryCommit();
    };

    // --- a realistic ReplicatedMergeTree coordination sequence (each quorum-final) ---
    const std::vector<Coordination::ZooKeeperRequestPtr> script = {
        createReq("/clickhouse", ""),
        createReq("/clickhouse/tables", ""),
        createReq("/clickhouse/tables/events", ""),
        createReq("/clickhouse/tables/events/replicas", ""),
        createReq("/clickhouse/tables/events/replicas/r1", "active"),
        createReq("/clickhouse/tables/events/block_numbers", "0"),
        setReq("/clickhouse/tables/events/block_numbers", "1"),
        setReq("/clickhouse/tables/events/block_numbers", "2"),
        createReq("/clickhouse/tables/events/leader_election", "r1"),
    };
    for (const auto & req : script)
    {
        auto r = coordinate(req, /*n_votes=*/4);  // 4 distinct, 80 stake > 66
        must(r.committed == 1, "entry reached a >2/3-stake quorum cert and committed");
    }

    must(commit_log.size() == script.size(), "commit fired once per entry");
    bool in_order = true;
    for (size_t i = 0; i < commit_log.size(); ++i)
        if (commit_log[i] != i + 1) in_order = false;
    must(in_order, "commits applied in strict log order");
    must(engine.lastCommittedIndex() == script.size(), "engine committed index == log length");

    // --- the REAL KeeperStorage must reflect the consensus-committed log ---
    auto & storage = state_machine->getStorageUnsafe();
    must(storage.container.contains("/clickhouse/tables/events/replicas/r1"), "replica r1 present");
    must(storage.container.contains("/clickhouse/tables/events/leader_election"), "leader_election present");
    must(storage.container.getValue("/clickhouse/tables/events/block_numbers").getData() == "2",
         "block_numbers == '2' (both SETs applied in order)");

    // --- safety: a sub-quorum request (3 < α votes) does NOT commit ---
    auto sub = coordinate(setReq("/clickhouse/tables/events/block_numbers", "3"), /*n_votes=*/3);
    must(sub.committed == 0, "sub-quorum request does NOT commit (no >2/3-stake cert)");
    must(engine.lastCommittedIndex() == script.size(), "committed index unchanged after sub-quorum");
    must(storage.container.getValue("/clickhouse/tables/events/block_numbers").getData() == "2",
         "block_numbers still '2' (the sub-quorum SET was not applied)");

    std::printf("committed %zu entries via quorum cert; sub-quorum rejected; storage OK\n", commit_log.size());

    if (g_failures)
    {
        std::printf("== %d assertion(s) FAILED ==\n", g_failures);
        return 1;
    }
    std::printf("== real KeeperStateMachine finalized by a >2/3-stake quorum cert — zero Raft ==\n");
    return 0;
}
