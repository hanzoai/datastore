#include <Coordination/QuasarKeeperConsensus.h>

#include <Common/Exception.h>
#include <Common/logger_useful.h>

#include <cstring>

extern "C" {
#include "lux_consensus.h"
}

namespace DB
{

namespace ErrorCodes
{
    extern const int RAFT_ERROR;
    extern const int LOGICAL_ERROR;
}

/// Owns the libluxconsensus chain handle. Kept out of the header so lux_consensus.h
/// stays a translation-unit-local dependency.
struct QuasarKeeperConsensus::Engine
{
    lux_chain_t * chain = nullptr;
    lux_config_t cfg{};
};

QuasarKeeperConsensus::QuasarKeeperConsensus(
    IKeeperStateMachine & state_machine_, KeeperContextPtr keeper_context_, uint32_t node_count_)
    : state_machine(state_machine_)
    , keeper_context(std::move(keeper_context_))
    , node_count(node_count_ == 0 ? 1 : node_count_)
    , engine(std::make_unique<Engine>())
{
}

QuasarKeeperConsensus::~QuasarKeeperConsensus()
{
    shutdown();
}

void QuasarKeeperConsensus::startup()
{
    if (running.load(std::memory_order_acquire))
        return;

    if (lux_consensus_init() != LUX_SUCCESS)
        throw Exception(ErrorCodes::RAFT_ERROR, "Failed to initialize Lux consensus engine");

    /// Snow-family sampling parameters. For a single node, k/alpha/beta=1 means
    /// one confidence vote finalizes; multi-node scales these to the peer set.
    engine->cfg.node_count = node_count;
    engine->cfg.k = node_count;
    engine->cfg.alpha = node_count;
    engine->cfg.beta = node_count;

    engine->chain = lux_chain_new(&engine->cfg);
    if (engine->chain == nullptr || lux_chain_start(engine->chain) != LUX_SUCCESS)
        throw Exception(ErrorCodes::RAFT_ERROR, "Failed to start Lux consensus chain");

    /// Single-node coordinator is always the leader; multi-node leadership is
    /// derived from the Quasar validator set (future stage).
    is_leader.store(node_count == 1, std::memory_order_release);
    running.store(true, std::memory_order_release);

    LOG_INFO(getLogger("QuasarKeeperConsensus"),
             "Quasar coordination engine started (nodes={}, leader={})", node_count, is_leader.load());
}

void QuasarKeeperConsensus::shutdown()
{
    if (!running.exchange(false, std::memory_order_acq_rel))
        return;
    if (engine->chain != nullptr)
    {
        lux_chain_stop(engine->chain);
        lux_chain_destroy(engine->chain);
        engine->chain = nullptr;
    }
    lux_consensus_cleanup();
    is_leader.store(false, std::memory_order_release);
}

bool QuasarKeeperConsensus::finalizeEntry(uint64_t height)
{
    /// Deterministic per-entry block id derived from its log position.
    uint8_t block_id[32];
    for (int i = 0; i < 32; ++i)
        block_id[i] = static_cast<uint8_t>((height * 7u + static_cast<uint64_t>(i)) & 0xffu);

    lux_block_t blk{};
    std::memcpy(blk.id, block_id, 32);
    std::memset(blk.parent_id, 0, 32);
    blk.height = height;
    blk.timestamp = static_cast<uint64_t>(1700000000ull + height);
    blk.data = nullptr;
    blk.data_size = 0;

    if (lux_chain_add_block(engine->chain, &blk) != LUX_SUCCESS)
        return false;

    bool accepted = false;
    for (uint32_t v = 0; v < engine->cfg.beta && !accepted; ++v)
    {
        lux_vote_t vote{};
        std::memcpy(vote.block_id, block_id, 32);
        for (int i = 0; i < 32; ++i)
            vote.voter_id[i] = static_cast<uint8_t>(v + 1);
        vote.is_preference = false;
        lux_consensus_process_vote(engine->chain, &vote);
        lux_consensus_is_accepted(engine->chain, block_id, &accepted);
    }
    return accepted;
}

QuasarKeeperConsensus::AppendOutcome QuasarKeeperConsensus::append(const KeeperRequestsForSessions & batch)
{
    AppendOutcome outcome;
    if (!running.load(std::memory_order_acquire) || !is_leader.load(std::memory_order_acquire))
        return outcome; /// not accepted: caller maps this to ZCONNECTIONLOSS, as with a non-leader NuRaft append

    /// Single committer: the ordered log is advanced under one lock, exactly as a
    /// Raft leader applies entries in index order.
    std::lock_guard lock(append_mutex);

    for (const auto & request_for_session : batch)
    {
        const uint64_t idx = next_log_idx.load(std::memory_order_relaxed) + 1;

        /// Two-phase, as the dispatcher drives NuRaft: preprocess at append
        /// (speculative, pre-consensus), commit once the order is final.
        KeeperRequestForSession rfs = request_for_session;
        if (rfs.zxid == 0)
            rfs.zxid = state_machine.getNextZxid();
        rfs.log_idx = idx;
        state_machine.preprocess(rfs, /*lock_mutex*/ true);

        auto buf = IKeeperStateMachine::getZooKeeperLogEntry(rfs);

        if (!finalizeEntry(idx))
            throw Exception(ErrorCodes::RAFT_ERROR, "Quasar failed to finalize coordination log entry {}", idx);

        /// commit() applies to KeeperStorage, pushes the response, fires the
        /// dispatcher's commit callback, and advances KeeperContext's committed
        /// index (the read-after-write barrier). We do not duplicate that work.
        state_machine.commit(idx, *buf);

        next_log_idx.store(idx, std::memory_order_relaxed);
        last_committed_idx.store(idx, std::memory_order_release);
        outcome.last_log_idx = idx;
    }

    outcome.accepted = true;
    return outcome;
}

}
