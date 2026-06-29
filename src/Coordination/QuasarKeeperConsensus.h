#pragma once

#include <Coordination/KeeperStateMachine.h>
#include <Coordination/KeeperContext.h>
#include <Coordination/KeeperCommon.h>

#include "lux/consensus2/quorum_cert_engine.hpp"
#include "lux/consensus2/wave.hpp"

#include <array>
#include <cstdint>
#include <map>
#include <memory>
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

    /// Build a SINGLE-NODE self-certifying coordinator: the embedded keeper is the
    /// sole validator. It mints one BLS keypair (deterministic from `node_seed`),
    /// registers a 1-validator set {self, stake=100} with α=1 and a degenerate wave
    /// (k=1, α=1.0, β=1), and signs its OWN ACCEPT vote for every entry — producing
    /// a GENUINE 1-of-1 quorum certificate (α distinct voters AND voted_stake 100 >
    /// floor(2/3·100)=66). This is real Quasar finality, not a bypass.
    ///
    /// TRUST MODEL (documented): with N=1 there is no Byzantine fault tolerance — a
    /// single node cannot tolerate its own failure; the certificate proves the node
    /// authored the entry. This is identical in replication guarantee to NuRaft
    /// single-node (which also has no replica). Multi-node BFT requires the ZAP vote
    /// transport gossiping votes between independent validators — a later stage.
    ///
    /// `start_index` continues the log index from the state machine's last committed
    /// index (snapshot/log recovery), so a restart does not re-issue index 1.
    static std::unique_ptr<QuasarKeeperConsensus> singleNode(
        IKeeperStateMachine & state_machine,
        std::uint64_t epoch,
        std::uint64_t node_seed,
        std::uint64_t start_index = 0);

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

    /// SINGLE-NODE drive: submit one request, self-certify it (drive the wave to
    /// Accept with one virtuous round, then sign and record this node's own ACCEPT
    /// vote → a 1-of-1 quorum cert), and commit the now-final contiguous prefix to
    /// the state machine. Returns the commit result (committed count + last index).
    /// Requires the engine to have been built via `singleNode` (it owns the key).
    /// This is the seam NuRaft's append+commit loop occupied, run synchronously.
    CommitResult appendLocal(const KeeperRequestForSession & request);

    bool isSingleNode() const { return single_node; }
    std::uint64_t lastCommittedIndex() const { return last_committed; }
    std::uint64_t totalStake() const { return gate.total_stake(); }

private:
    IKeeperStateMachine & state_machine;
    const std::uint64_t epoch;
    std::uint64_t next_idx = 0;
    std::uint64_t last_committed = 0;

    /// Single-node self-validator material. `self_sk` is the 32-byte BLS secret key
    /// (held only in process memory, never persisted or gossiped — single-node votes
    /// are minted and verified in-process); `self_pk` is its 48-byte compressed G1
    /// public key, the lone entry of the validator set. Empty unless built via
    /// `singleNode`.
    bool single_node = false;
    std::array<std::uint8_t, 32> self_sk{};
    lux::consensus2::PubKey self_pk{};

    lux::consensus2::QuorumCertEngine gate;
    lux::consensus2::Wave wave;

    struct Pending
    {
        nuraft::ptr<nuraft::buffer> buf;  /// the serialized ZooKeeper log entry
        std::uint64_t idx = 0;
    };
    std::map<lux::consensus2::BlockId, Pending> pending;        /// in-flight only; erased on finality
    std::map<std::uint64_t, nuraft::ptr<nuraft::buffer>> ready; /// idx → entry awaiting a whole prefix
};

}
