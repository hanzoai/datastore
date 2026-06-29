#include <Coordination/QuasarKeeperConsensus.h>

#include "bls_signature.hpp"

#include <stdexcept>

namespace DB
{

namespace
{
    /// Deterministic, distinct block id per log index. The quorum cert binds the
    /// canonical message (block id + height + epoch), so a per-index id is enough
    /// to make each entry's certificate unique and position-bound.
    lux::consensus2::BlockId blockIdOf(std::uint64_t idx)
    {
        lux::consensus2::BlockId b{};
        for (int i = 0; i < 8; ++i)
            b[i] = static_cast<std::uint8_t>(idx >> (56 - 8 * i));
        return b;
    }
}

std::unique_ptr<QuasarKeeperConsensus> QuasarKeeperConsensus::singleNode(
    IKeeperStateMachine & state_machine_,
    std::uint64_t epoch_,
    std::uint64_t node_seed,
    std::uint64_t start_index)
{
    /// Deterministic BLS keypair from the node identity. A single-node keeper's
    /// vote is self-consistent within the process; the seed need only be stable,
    /// not secret-managed (the key never leaves memory).
    std::array<std::uint8_t, 32> seed{};
    for (int i = 0; i < 8; ++i)
        seed[i] = static_cast<std::uint8_t>(node_seed >> (56 - 8 * i));

    std::array<std::uint8_t, 32> sk{};
    if (cevm::crypto::bls::keygen(seed.data(), sk.data()) != 0)
        throw std::runtime_error("QuasarKeeperConsensus::singleNode: BLS keygen failed");

    lux::consensus2::PubKey pk{};
    if (cevm::crypto::bls::sk_to_pk(sk.data(), pk.data()) != 0)
        throw std::runtime_error("QuasarKeeperConsensus::singleNode: BLS sk_to_pk failed");

    /// One validator, stake 100: voted 100 > floor(2/3·100)=66 with α=1 distinct
    /// voter ⇒ a real, fail-closed quorum certificate of size one.
    std::vector<lux::consensus2::Validator> set{lux::consensus2::Validator{pk, 100}};

    auto engine = std::make_unique<QuasarKeeperConsensus>(
        state_machine_,
        std::move(set),
        /*alpha=*/1u,
        lux::consensus2::WaveConfig{/*k=*/1u, /*alpha=*/1.0, /*beta=*/1u},
        epoch_);

    engine->single_node = true;
    engine->self_sk = sk;
    engine->self_pk = pk;
    /// Continue the log from where the state machine left off (snapshot/log recovery);
    /// a fresh keeper starts at 0 so the first entry takes index 1.
    engine->next_idx = start_index;
    engine->last_committed = start_index;
    return engine;
}

QuasarKeeperConsensus::CommitResult QuasarKeeperConsensus::appendLocal(const KeeperRequestForSession & request)
{
    if (!single_node)
        throw std::runtime_error("QuasarKeeperConsensus::appendLocal called on a non-single-node engine");

    /// 1) Order + preprocess (speculative, pre-consensus), returning the position
    ///    this entry's certificate binds to.
    const lux::consensus2::VotePosition pos = submit(request);

    /// 2) Liveness: one virtuous poll round (k=1, all-yes) latches wave Accept (β=1).
    recordPoll(pos.block_id, /*yes=*/1u, /*total=*/1u);

    /// 3) Safety: sign and record THIS node's ACCEPT vote over the canonical message
    ///    → the gate now holds α=1 distinct voter with > 2/3 stake ⇒ final.
    const std::vector<std::uint8_t> msg = lux::consensus2::canonical_vote_message(pos);
    lux::consensus2::Signature sig{};
    if (cevm::crypto::bls::sign(self_sk.data(), msg.data(), msg.size(), sig.data()) != 0)
        throw std::runtime_error("QuasarKeeperConsensus::appendLocal: BLS sign failed");
    recordVote(pos.block_id, self_pk, sig);

    /// 4) Commit the now-final contiguous prefix to the state machine.
    return tryCommit();
}

QuasarKeeperConsensus::QuasarKeeperConsensus(
    IKeeperStateMachine & state_machine_,
    std::vector<lux::consensus2::Validator> validators,
    std::uint32_t alpha,
    lux::consensus2::WaveConfig wave_cfg,
    std::uint64_t epoch_)
    : state_machine(state_machine_)
    , epoch(epoch_)
    , gate(std::move(validators), alpha)
    , wave(wave_cfg)
{
}

lux::consensus2::VotePosition QuasarKeeperConsensus::submit(const KeeperRequestForSession & request)
{
    const std::uint64_t idx = ++next_idx;

    /// Two-phase, as the dispatcher drove NuRaft: preprocess at append (speculative,
    /// pre-consensus), commit once the order is final.
    KeeperRequestForSession rfs = request;
    if (rfs.zxid == 0)
        rfs.zxid = state_machine.getNextZxid();
    rfs.log_idx = idx;
    state_machine.preprocess(rfs, /*lock_mutex*/ true);

    auto buf = IKeeperStateMachine::getZooKeeperLogEntry(rfs);

    lux::consensus2::VotePosition pos{};
    pos.block_id = blockIdOf(idx);
    pos.height = idx;
    pos.epoch = epoch;

    gate.submit(pos);
    pending[pos.block_id] = Pending{buf, idx};
    return pos;
}

lux::consensus2::Decision QuasarKeeperConsensus::recordPoll(
    const lux::consensus2::BlockId & block_id, std::uint32_t yes, std::uint32_t total)
{
    const auto it = pending.find(block_id);
    if (it == pending.end())
        return lux::consensus2::Decision::Undecided;
    return wave.record_round(block_id, yes, total);  // wave keys on the full block id (M4)
}

lux::consensus2::VoteResult QuasarKeeperConsensus::recordVote(
    const lux::consensus2::BlockId & block_id,
    const lux::consensus2::PubKey & voter,
    const lux::consensus2::Signature & sig)
{
    return gate.record_vote(block_id, voter, sig);
}

QuasarKeeperConsensus::CommitResult QuasarKeeperConsensus::tryCommit()
{
    /// 1) Promote entries that have reached BOTH liveness (wave Accept) and safety
    ///    (a >2/3-stake quorum cert) into the ready queue, keyed by log index.
    /// ...then ERASE finalized entries from `pending` and drop their votes from the
    /// gate, so the scan walks in-flight entries only (no O(N²) re-walk of finalized
    /// state) and memory stays bounded (no retained vote sets) — both flagged by the
    /// coordination benchmark.
    for (auto it = pending.begin(); it != pending.end();)
    {
        const auto & block_id = it->first;
        if (wave.decision(block_id) == lux::consensus2::Decision::Accept
            && gate.is_final(block_id) && gate.assemble_cert(block_id))
        {
            ready.emplace(it->second.idx, it->second.buf);
            gate.drop(block_id);            /// release the gate's accumulated votes
            it = pending.erase(it);          /// shrink the working set
        }
        else
            ++it;
    }

    /// 2) Apply a contiguous prefix to the state machine, in strict index order —
    ///    the slot NuRaft's commit loop occupied.
    CommitResult result;
    for (;;)
    {
        const std::uint64_t want = last_committed + 1;
        const auto it = ready.find(want);
        if (it == ready.end())
            break;
        state_machine.commit(want, *it->second);
        last_committed = want;
        ready.erase(it);
        ++result.committed;
    }
    result.last_log_idx = last_committed;
    return result;
}

}
