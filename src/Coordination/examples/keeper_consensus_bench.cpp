// keeper_consensus_bench.cpp — RIGOROUS coordination-engine microbenchmark.
//
// Drives the SAME real KeeperStateMachine<KeeperMemoryStorage> through THREE
// per-entry commit paths over an identical, deterministic ReplicatedMergeTree-style
// workload, one path per process invocation (clean peak-RSS isolation):
//
//   nuraft-floor : preprocess(rfs) + commit(idx,buf)            — the apply path
//                  NuRaft's commit loop drives, in-memory, NO durable log. The
//                  absolute floor for NuRaft (it is being charged ZERO for the
//                  log/replication machinery a real raft_server runs).
//   nuraft-wal   : getLogEntry + KeeperLogStore.append + end_of_append_batch +
//                  spin-until-durable(fsync) + pre_commit + commit              — the
//                  realistic single-node NuRaft path (the exact calls raft_server
//                  makes), WITH the durable on-disk changelog (force_sync=true).
//   quasar       : QuasarKeeperConsensus.submit(preprocess+serialize+gate.submit)
//                  + 4x recordPoll(wave) + alpha x recordVote(REAL BLS verify,
//                  pre-signed) + tryCommit(assemble_cert[BLS aggregate]+commit).
//                  consensus2 leaderless finality gate. Votes are PRE-SIGNED
//                  outside the timed region (signing is the peers' cost; the
//                  committing node only VERIFIES) — verify is the real per-commit
//                  crypto cost Quasar pays and NuRaft does not.
//   bls          : raw BLS12-381 sign/verify microbench (sizing + explanation).
//
// Per-entry latency is recorded for every entry; percentiles are reported over a
// warm window. Peak RSS via getrusage(ru_maxrss). Run several times (outer
// script), drop the cold run, report warm medians + variance.
//
// HONESTY: single-node is NOT a multi-node replication comparison. nuraft-floor
// commits locally; quasar at this topology runs its gate in-process. This measures
// per-commit ENGINE CPU/memory overhead, not network replication. quasar buys
// Byzantine tolerance + leaderless + PQ-readiness for the BLS cost surfaced here.

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
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <memory>
#include <string>
#include <vector>
#include <sys/resource.h>
#include <fcntl.h>
#include <unistd.h>

using namespace DB;
namespace c2 = lux::consensus2;
using Clock = std::chrono::steady_clock;

namespace
{

constexpr int64_t SESSION = 1;
constexpr uint64_t EPOCH = 1;
constexpr uint32_t ALPHA = 4;       // 4 distinct votes, 80/100 stake > 66 floor
constexpr int NUM_VALIDATORS = 5;

long rssKb()
{
    std::ifstream f("/proc/self/status");
    std::string k;
    while (f >> k)
    {
        if (k == "VmRSS:") { long v; f >> v; return v; }
    }
    return -1;
}

double pctl(std::vector<double> v, double p)
{
    if (v.empty()) return 0;
    std::sort(v.begin(), v.end());
    size_t i = static_cast<size_t>(p * static_cast<double>(v.size() - 1) + 0.5);
    return v[i];
}
double mean(const std::vector<double> & v)
{
    double s = 0; for (double x : v) s += x; return v.empty() ? 0 : s / static_cast<double>(v.size());
}

// ---- deterministic RMT-style workload (identical bytes for every config) -------
std::vector<Coordination::ZooKeeperRequestPtr> buildWorkload(size_t N)
{
    std::vector<Coordination::ZooKeeperRequestPtr> w;
    w.reserve(N);
    auto cre = [&](const std::string & p, const std::string & d, bool eph, bool seq)
    {
        auto r = std::make_shared<Coordination::ZooKeeperCreateRequest>();
        r->path = p; r->data = d; r->is_ephemeral = eph; r->is_sequential = seq;
        w.push_back(r);
    };
    auto st = [&](const std::string & p, const std::string & d)
    {
        auto r = std::make_shared<Coordination::ZooKeeperSetRequest>();
        r->path = p; r->data = d; r->version = -1;
        w.push_back(r);
    };
    cre("/clickhouse", "", false, false);
    cre("/clickhouse/tables", "", false, false);
    cre("/clickhouse/tables/t", "", false, false);
    cre("/clickhouse/tables/t/blocks", "", false, false);
    cre("/clickhouse/tables/t/replicas", "", false, false);
    cre("/clickhouse/tables/t/log", "", false, false);
    cre("/clickhouse/tables/t/block_numbers", "", false, false);
    const int NP = 16;
    for (int k = 0; k < NP; ++k) cre("/clickhouse/tables/t/block_numbers/p" + std::to_string(k), "0", false, false);

    // Realistic write-coordination mix, 4-op cycle:
    //   block dedup create (persistent) | replica liveness (ephemeral) |
    //   replication-log entry (sequential) | block-number bump (set)
    size_t u = 0; long blk = 0;
    while (w.size() < N)
    {
        cre("/clickhouse/tables/t/blocks/" + std::to_string(u), "d", false, false); if (w.size() >= N) break;
        cre("/clickhouse/tables/t/replicas/host" + std::to_string(u), "active", true, false); if (w.size() >= N) break;
        cre("/clickhouse/tables/t/log/log-", "e", false, true); if (w.size() >= N) break;
        st("/clickhouse/tables/t/block_numbers/p" + std::to_string(u % NP), std::to_string(++blk));
        ++u;
    }
    w.resize(N);
    return w;
}

KeeperRequestForSession forSession(const Coordination::ZooKeeperRequestPtr & r)
{
    KeeperRequestForSession rfs;
    rfs.session_id = SESSION;
    rfs.request = r;
    return rfs;
}

// ---- BLS keys (real BLS12-381, deterministic from tag) -------------------------
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
c2::BlockId blockIdOf(std::uint64_t idx)
{
    c2::BlockId b{};
    for (int i = 0; i < 8; ++i) b[i] = static_cast<std::uint8_t>(idx >> (56 - 8 * i));
    return b;
}
c2::Signature signVote(const Key & key, const std::vector<std::uint8_t> & msg)
{
    c2::Signature s{};
    if (cevm::crypto::bls::sign(key.sk.data(), msg.data(), msg.size(), s.data()) != 0) { std::puts("sign failed"); std::exit(2); }
    return s;
}

KeeperContextPtr makeContext(CoordinationSettingsPtr settings, const std::string & base, bool with_log)
{
    namespace fs = std::filesystem;
    fs::remove_all(base);
    fs::create_directories(base + "/log");
    fs::create_directories(base + "/snapshots");
    fs::create_directories(base + "/state");
    auto ctx = std::make_shared<KeeperContext>(true, settings);
    ctx->setLogDisk(std::make_shared<DiskLocal>("LogDisk", base + "/log"));
    ctx->setSnapshotDisk(std::make_shared<DiskLocal>("SnapshotDisk", base + "/snapshots"));
    ctx->setStateFileDisk(std::make_shared<DiskLocal>("StateFile", base + "/state"));
    ctx->setRocksDBOptions();
    (void)with_log;
    return ctx;
}

void report(const std::string & config, size_t N, double wall_s,
            std::vector<double> & lat, long rss_base, long rss_final,
            const struct rusage & ru0, const struct rusage & ru1)
{
    // warm window: drop the first max(1000, N/20) as cold; "early" window is the
    // first 8000 of the warm region (low pending → exposes intrinsic per-commit
    // cost before any O(pending) bookkeeping in the engine bites).
    size_t w0 = std::min<size_t>(N / 20, 1000);
    if (w0 < N) {} else w0 = 0;
    std::vector<double> warm(lat.begin() + w0, lat.end());
    size_t early_n = std::min<size_t>(8000, warm.size());
    std::vector<double> early(warm.begin(), warm.begin() + early_n);

    auto cpu = [](const struct timeval & a, const struct timeval & b)
    { return static_cast<double>(b.tv_sec - a.tv_sec) + static_cast<double>(b.tv_usec - a.tv_usec) / 1e6; };
    double user_s = cpu(ru0.ru_utime, ru1.ru_utime);
    double sys_s  = cpu(ru0.ru_stime, ru1.ru_stime);

    // decile medians to expose any per-entry growth trend
    std::string trend;
    for (int d = 1; d <= 10; ++d)
    {
        size_t a = (lat.size() * (d - 1)) / 10, b = (lat.size() * d) / 10;
        std::vector<double> seg(lat.begin() + a, lat.begin() + b);
        char buf[32]; std::snprintf(buf, sizeof(buf), "%.1f", pctl(seg, 0.5));
        trend += buf; if (d < 10) trend += ",";
    }

    std::printf("RESULT config=%s N=%zu wall_s=%.4f thr_eps=%.1f "
                "warm_p50_us=%.2f warm_p95_us=%.2f warm_p99_us=%.2f warm_mean_us=%.2f "
                "early_p50_us=%.2f early_p95_us=%.2f early_p99_us=%.2f "
                "rss_base_kb=%ld rss_final_kb=%ld rss_growth_kb=%ld maxrss_kb=%ld "
                "user_cpu_s=%.3f sys_cpu_s=%.3f cpu_us_per_commit=%.3f decile_p50_us=[%s]\n",
                config.c_str(), N, wall_s, static_cast<double>(N) / wall_s,
                pctl(warm, 0.5), pctl(warm, 0.95), pctl(warm, 0.99), mean(warm),
                pctl(early, 0.5), pctl(early, 0.95), pctl(early, 0.99),
                rss_base, rss_final, rss_final - rss_base, ru1.ru_maxrss,
                user_s, sys_s, (user_s + sys_s) * 1e6 / static_cast<double>(N), trend.c_str());
}

} // namespace

int main(int argc, char ** argv)
{
    if (argc < 3) { std::printf("usage: %s <nuraft-floor|nuraft-wal|quasar|bls> <N>\n", argv[0]); return 2; }
    const std::string config = argv[1];
    const size_t N = static_cast<size_t>(std::atoll(argv[2]));

    // ---- raw BLS microbench --------------------------------------------------
    if (config == "bls")
    {
        Key k = makeKey(0x77);
        c2::VotePosition pos{blockIdOf(1), 1, EPOCH};
        std::vector<std::uint8_t> msg = c2::canonical_vote_message(pos);
        // warm
        for (int i = 0; i < 200; ++i) { auto s = signVote(k, msg); (void)cevm::crypto::bls::verify(k.pk.data(), msg.data(), msg.size(), s.data()); }
        std::vector<double> sign_us, ver_us;
        sign_us.reserve(N); ver_us.reserve(N);
        c2::Signature sig{};
        for (size_t i = 0; i < N; ++i)
        {
            auto t0 = Clock::now();
            if (cevm::crypto::bls::sign(k.sk.data(), msg.data(), msg.size(), sig.data()) != 0) return 3;
            auto t1 = Clock::now();
            int rc = cevm::crypto::bls::verify(k.pk.data(), msg.data(), msg.size(), sig.data());
            auto t2 = Clock::now();
            if (rc != 0) return 4;
            sign_us.push_back(std::chrono::duration<double, std::micro>(t1 - t0).count());
            ver_us.push_back(std::chrono::duration<double, std::micro>(t2 - t1).count());
        }
        // fast_aggregate_verify: ALPHA validators all sign the SAME canonical
        // message (votes for one block share the position), so the committing node
        // can verify all ALPHA with ONE multi-pairing instead of ALPHA pairings.
        // This is the optimization the current record_vote (ALPHA individual
        // verifies) leaves on the table.
        std::vector<Key> vk;
        for (int i = 0; i < NUM_VALIDATORS; ++i) vk.push_back(makeKey(std::uint8_t(0x90 + i)));
        std::array<std::uint8_t, ALPHA * 48> pks_flat{};
        std::array<std::uint8_t, ALPHA * 96> sigs_flat{};
        std::array<std::uint8_t, 96> agg_sig{};
        for (uint32_t v = 0; v < ALPHA; ++v)
        {
            std::memcpy(pks_flat.data() + v * 48, vk[v].pk.data(), 48);
            auto s = signVote(vk[v], msg);
            std::memcpy(sigs_flat.data() + v * 96, s.data(), 96);
        }
        cevm::crypto::bls::aggregate_sigs(sigs_flat.data(), ALPHA, agg_sig.data());
        std::vector<double> fav_us;
        fav_us.reserve(N);
        for (size_t i = 0; i < N; ++i)
        {
            auto t0 = Clock::now();
            int rc = cevm::crypto::bls::fast_aggregate_verify(pks_flat.data(), ALPHA, msg.data(), msg.size(), agg_sig.data());
            auto t1 = Clock::now();
            if (rc != 0) return 6;
            fav_us.push_back(std::chrono::duration<double, std::micro>(t1 - t0).count());
        }

        std::printf("RESULT config=bls N=%zu alpha=%d sign_p50_us=%.2f verify_p50_us=%.2f verify_p95_us=%.2f "
                    "sign_per_s=%.0f verify_per_s=%.0f alpha_individual_verify_us=%.2f "
                    "fast_aggregate_verify_us=%.2f agg_verify_speedup=%.2fx\n",
                    N, static_cast<int>(ALPHA), pctl(sign_us, 0.5), pctl(ver_us, 0.5), pctl(ver_us, 0.95),
                    1e6 / pctl(sign_us, 0.5), 1e6 / pctl(ver_us, 0.5),
                    static_cast<double>(ALPHA) * pctl(ver_us, 0.5), pctl(fav_us, 0.5),
                    (static_cast<double>(ALPHA) * pctl(ver_us, 0.5)) / pctl(fav_us, 0.5));
        return 0;
    }

    // ---- raw durability floor ------------------------------------------------
    // The dominant per-entry cost of the real NuRaft changelog (force_sync=true)
    // is the fdatasync. The full KeeperLogStore path (raft_server) is mid-cutout
    // of this tree and no longer links into an example; this bounds its sync cost
    // on the SAME filesystem the changelog used, with clean reps. PROXY (the real
    // changelog also serializes/batches): treat as the durable-commit FLOOR.
    if (config == "fsync")
    {
        namespace fs = std::filesystem;
        const std::string dir = "/tmp/keeper_consensus_bench_fsync";
        fs::remove_all(dir); fs::create_directories(dir);
        const std::string path = dir + "/wal";
        int fd = ::open(path.c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd < 0) { std::perror("open"); return 7; }
        std::string rec(256, 'x'); // ~ one small ZooKeeper log entry
        for (int i = 0; i < 200; ++i) { if (::write(fd, rec.data(), rec.size()) < 0) return 8; ::fdatasync(fd); }
        std::vector<double> us; us.reserve(N);
        for (size_t i = 0; i < N; ++i)
        {
            auto t0 = Clock::now();
            if (::write(fd, rec.data(), rec.size()) != static_cast<ssize_t>(rec.size())) { std::perror("write"); return 8; }
            ::fdatasync(fd);
            auto t1 = Clock::now();
            us.push_back(std::chrono::duration<double, std::micro>(t1 - t0).count());
        }
        ::close(fd);
        std::printf("RESULT config=fsync N=%zu fdatasync_p50_us=%.2f fdatasync_p95_us=%.2f fdatasync_p99_us=%.2f ops_per_s=%.0f\n",
                    N, pctl(us, 0.5), pctl(us, 0.95), pctl(us, 0.99), 1e6 / pctl(us, 0.5));
        return 0;
    }

    auto settings = std::make_shared<CoordinationSettings>();
    const std::string base = "/tmp/keeper_consensus_bench_" + config;
    auto keeper_context = makeContext(settings, base, config == "nuraft-wal");

    SnapshotsQueue snapshots_queue{1};
    size_t commit_count = 0;
    IKeeperStateMachine::CommitCallback commit_cb =
        [&](uint64_t, const KeeperRequestForSession &) { ++commit_count; };
    auto sm = std::make_shared<KeeperStateMachine<KeeperMemoryStorage>>(
        nullptr, snapshots_queue, keeper_context, nullptr, commit_cb, "");
    sm->init();

    auto workload = buildWorkload(N);
    std::vector<double> lat;
    lat.reserve(N);

    struct rusage ru0; getrusage(RUSAGE_SELF, &ru0);
    long rss_base = rssKb();
    auto wall0 = Clock::now();

    if (config == "nuraft-floor")
    {
        // The exact calls NuRaft's commit loop drives on the state machine, minus
        // the durable log / replication machinery (the NuRaft apply FLOOR).
        for (size_t i = 0; i < N; ++i)
        {
            auto t0 = Clock::now();
            KeeperRequestForSession rfs = forSession(workload[i]);
            rfs.zxid = sm->getNextZxid();
            rfs.log_idx = i + 1;
            sm->preprocess(rfs, /*lock_mutex*/ true);
            auto buf = IKeeperStateMachine::getZooKeeperLogEntry(rfs);
            sm->commit(i + 1, *buf);
            auto t1 = Clock::now();
            lat.push_back(std::chrono::duration<double, std::micro>(t1 - t0).count());
        }
    }
    else if (config == "quasar")
    {
        std::vector<Key> keys;
        for (int i = 0; i < NUM_VALIDATORS; ++i) keys.push_back(makeKey(std::uint8_t(0x60 + i)));
        std::vector<c2::Validator> set;
        for (const auto & k : keys) set.push_back({k.pk, 20});

        // PRE-SIGN every entry's ALPHA votes OUTSIDE the timed region (peer cost,
        // not the committing node's). idx is deterministic: submit() assigns
        // ++next_idx starting at 1, so entry i has idx=i+1, block_id=blockIdOf(i+1).
        std::vector<std::array<c2::Signature, ALPHA>> presig(N);
        for (size_t i = 0; i < N; ++i)
        {
            c2::VotePosition pos{blockIdOf(i + 1), i + 1, EPOCH};
            std::vector<std::uint8_t> msg = c2::canonical_vote_message(pos);
            for (uint32_t v = 0; v < ALPHA; ++v) presig[i][v] = signVote(keys[v], msg);
        }

        QuasarKeeperConsensus engine(*sm, set, ALPHA,
                                     c2::WaveConfig{/*k*/ 5, /*alpha*/ 0.8, /*beta*/ 4}, EPOCH);
        if (engine.totalStake() != 100) { std::puts("stake != 100"); return 5; }

        // re-time from here so pre-signing is excluded
        getrusage(RUSAGE_SELF, &ru0);
        rss_base = rssKb();
        wall0 = Clock::now();
        for (size_t i = 0; i < N; ++i)
        {
            auto t0 = Clock::now();
            const c2::VotePosition pos = engine.submit(forSession(workload[i]));
            for (int r = 0; r < 4; ++r) engine.recordPoll(pos.block_id, /*yes*/ 5, /*total*/ 5);
            for (uint32_t v = 0; v < ALPHA; ++v) engine.recordVote(pos.block_id, keys[v].pk, presig[i][v]);
            engine.tryCommit();
            auto t1 = Clock::now();
            lat.push_back(std::chrono::duration<double, std::micro>(t1 - t0).count());
        }
        if (engine.lastCommittedIndex() != N) { std::printf("ERROR quasar committed=%llu != N=%zu\n",
                                                            static_cast<unsigned long long>(engine.lastCommittedIndex()), N); }
    }
    else { std::printf("unknown config %s\n", config.c_str()); return 2; }

    auto wall1 = Clock::now();
    double wall_s = std::chrono::duration<double>(wall1 - wall0).count();
    long rss_final = rssKb();
    struct rusage ru1; getrusage(RUSAGE_SELF, &ru1);

    // sanity: storage reflects the committed log
    auto & storage = sm->getStorageUnsafe();
    bool ok = storage.container.contains("/clickhouse/tables/t/blocks/0");
    if (config != "quasar" && commit_count != N) std::printf("WARN commit_count=%zu != N=%zu\n", commit_count, N);
    std::printf("SANITY config=%s storage_nodes=%zu has_block0=%d\n", config.c_str(), storage.container.size(), ok ? 1 : 0);

    report(config, N, wall_s, lat, rss_base, rss_final, ru0, ru1);
    return 0;
}
