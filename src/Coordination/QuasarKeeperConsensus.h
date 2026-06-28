#pragma once

#include <Coordination/KeeperStateMachine.h>
#include <Coordination/KeeperContext.h>
#include <Coordination/KeeperCommon.h>

#include "lux/consensus2/quorum_cert_engine.hpp"
#include "lux/consensus2/wave.hpp"

#include <cstdint>
#include <map>
#include <vector>

namespace DB
{

/// Consensus2-backed Keeper coordination — the REAL leaderless Lux consensus
/// (consensus2: photon/wave liveness + a >2/3-stake BLS quorum certificate) in
/// place of NuRaft. It orders ZooKeeper write requests and applies them to the
/// `KeeperStateMachine` in consensus order. The ZooKeeper API
/// (`KeeperStateMachine`/`KeeperStorage`) is unchanged — only the ordering engine
/// changes. The join point is `KeeperStateMachine::commit(log_idx, buf)`.
///
/// This replaces the earlier toy `libluxconsensus` backend: finality here is a
/// genuine quorum certificate (α distinct validators AND strictly > 2/3 stake),
/// NOT a local counter. Votes come from the validator set (injected in-process
/// for the test; gossiped over the network in a real keeper cluster — the
/// transport layer is a later stage). `nuraft::buffer` remains only as the state
/// machine's serialized-entry container, not as a consensus dependency.
class QuasarKeeperConsensus
{
public:
    /// Result of attempting to commit the finalized prefix.
    struct CommitResult
    {
        std::size_t committed = 0;     /// entries newly applied to the state machine
        std::uint64_t last_log_idx = 0;
    };

    QuasarKeeperConsensus(
        IKeeperStateMachine & state_machine_,
        std::vector<lux::consensus2::Validator> validators,
        std::uint32_t alpha,
        lux::consensus2::WaveConfig wave_cfg,
        std::uint64_t epoch_);

    QuasarKeeperConsensus(const QuasarKeeperConsensus &) = delete;
    QuasarKeeperConsensus & operator=(const QuasarKeeperConsensus &) = delete;

    /// Assign the next log index, preprocess the request against the state machine
    /// (the speculative pre-consensus phase), and register the entry for voting.
    /// Returns the consensus position validators sign over.
    lux::consensus2::VotePosition submit(const KeeperRequestForSession & request);

    /// Liveness: feed one poll round's tally for a pending entry.
    lux::consensus2::Decision recordPoll(const lux::consensus2::BlockId & block_id, std::uint32_t yes, std::uint32_t total);

    /// Safety: record a validator's signed ACCEPT vote for a pending entry.
    lux::consensus2::VoteResult recordVote(
        const lux::consensus2::BlockId & block_id,
        const lux::consensus2::PubKey & voter,
        const lux::consensus2::Signature & sig);

    /// Commit every entry that has reached BOTH wave-Accept and a >2/3-stake
    /// quorum cert, applying to the state machine in strict contiguous index order
    /// (out-of-order finality is buffered). This is the seam where NuRaft used to
    /// call `commit`.
    CommitResult tryCommit();

    std::uint64_t lastCommittedIndex() const { return last_committed; }
    std::uint64_t totalStake() const { return gate.total_stake(); }

private:
    IKeeperStateMachine & state_machine;
    const std::uint64_t epoch;
    std::uint64_t next_idx = 0;
    std::uint64_t last_committed = 0;

    lux::consensus2::QuorumCertEngine gate;
    lux::consensus2::Wave wave;

    struct Pending
    {
        nuraft::ptr<nuraft::buffer> buf;  /// the serialized ZooKeeper log entry
        std::uint64_t idx = 0;
        std::uint64_t item = 0;           /// wave handle (first 8 bytes of block id)
        bool ready = false;               /// finality reached, queued for in-order commit
    };
    std::map<lux::consensus2::BlockId, Pending> pending;
    std::map<std::uint64_t, nuraft::ptr<nuraft::buffer>> ready;  /// idx → entry awaiting a whole prefix
};

}
