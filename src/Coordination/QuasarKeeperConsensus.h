#pragma once

#include <Coordination/KeeperStateMachine.h>
#include <Coordination/KeeperContext.h>
#include <Coordination/KeeperCommon.h>

#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>

namespace DB
{

/// Native consensus engine for Keeper coordination, backed by Lux Quasar
/// (libluxconsensus) in place of NuRaft.
///
/// Keeper is two separable things: the ZooKeeper API (`KeeperStateMachine` over
/// `KeeperStorage`, the contract `Replicated*` speaks) and the consensus engine
/// that orders write requests and drives them through that state machine. This
/// class is the second thing, decomplected from Raft: it assigns each request a
/// monotonic log index, gets agreement on the order via Quasar, then runs the
/// state machine's two-phase `pre_commit`/`commit` in that order. The state
/// machine (unchanged) does the rest — pushes responses, fires the dispatcher's
/// commit callback, and advances `KeeperContext`'s committed index that the
/// read-after-write barrier waits on.
///
/// Single-node mode is complete and is the dominant Datastore deployment: the
/// node is always leader, ordering is local, and a 1-of-1 quorum finalizes each
/// entry immediately. Multi-node (Quasar agreement across keeper peers over ZAP
/// transport) extends `append`/leadership without changing this contract.
class QuasarKeeperConsensus
{
public:
    /// Result of ordering+committing one batch. Mirrors what the dispatcher
    /// reads back from NuRaft's append result: whether it was accepted, and the
    /// last committed log index (the read-after-write barrier value).
    struct AppendOutcome
    {
        bool accepted = false;
        uint64_t last_log_idx = 0;
    };

    QuasarKeeperConsensus(IKeeperStateMachine & state_machine_, KeeperContextPtr keeper_context_, uint32_t node_count_ = 1);
    ~QuasarKeeperConsensus();

    QuasarKeeperConsensus(const QuasarKeeperConsensus &) = delete;
    QuasarKeeperConsensus & operator=(const QuasarKeeperConsensus &) = delete;

    /// Bring up the Quasar chain. Idempotent; throws on engine init failure.
    void startup();

    /// Tear the chain down.
    void shutdown();

    /// Order and commit a batch of write requests. Returns once every request in
    /// the batch has reached consensus finality and been committed to the state
    /// machine, in order. Equivalent to NuRaft's `append_entries` followed by
    /// commit, but leaderless.
    AppendOutcome append(const KeeperRequestsForSessions & batch);

    bool isLeader() const { return is_leader.load(std::memory_order_acquire); }
    bool isLeaderAlive() const { return is_leader.load(std::memory_order_acquire); }
    bool isRunning() const { return running.load(std::memory_order_acquire); }
    uint64_t lastCommittedIndex() const { return last_committed_idx.load(std::memory_order_acquire); }

private:
    IKeeperStateMachine & state_machine;
    KeeperContextPtr keeper_context;
    const uint32_t node_count;

    /// Hides the libluxconsensus C handle so lux_consensus.h does not leak into
    /// every includer of this header.
    struct Engine;
    std::unique_ptr<Engine> engine;

    std::mutex append_mutex; /// serializes the ordered log (single committer)
    std::atomic<uint64_t> next_log_idx{0};
    std::atomic<uint64_t> last_committed_idx{0};
    std::atomic<bool> is_leader{false};
    std::atomic<bool> running{false};

    /// Drive confidence votes for one entry until the engine finalizes it.
    bool finalizeEntry(uint64_t height);
};

}
