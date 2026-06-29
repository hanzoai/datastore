#pragma once

#include <Common/Stopwatch.h>
#include <Coordination/InMemoryLogStore.h>
#include <Coordination/KeeperStateMachine.h>
#include <Coordination/KeeperStateManager.h>
#include <Poco/Util/AbstractConfiguration.h>
#include <Coordination/Keeper4LWInfo.h>
#include <Coordination/KeeperContext.h>
#include <Coordination/RaftServerConfig.h>

#include <memory>
#include <mutex>

namespace DB
{

/// The async-append result the request dispatchers consume. `nuraft::cmd_result`
/// is a header-only template (the TYPE substrate stays); the raft ENGINE that used
/// to fill it is gone. Single-node Quasar fills it synchronously — accepted, OK,
/// carrying the committed log index for the read-after-write barrier.
using RaftAppendResult = nuraft::ptr<nuraft::cmd_result<nuraft::ptr<nuraft::buffer>>>;

/// The leaderless Lux consensus engine (consensus2) that replaced the NuRaft raft
/// algorithm. Forward-declared so the consensus2/BLS headers stay out of every
/// translation unit that merely includes KeeperServer.h.
class QuasarKeeperConsensus;
class KeeperServer;

struct KeeperConfiguration;
using KeeperConfigurationPtr = std::shared_ptr<KeeperConfiguration>;

/// Single-node append "stream": the synchronous replacement for NuRaft's
/// `client_req_stream`. Because the embedded node is the sole validator, an append
/// commits SYNCHRONOUSLY through Quasar before returning — there is no in-flight
/// window, no leader to lose, nothing to abandon. The streaming dispatcher's
/// stream-state predicates therefore collapse to constants. Multi-node streaming
/// over the ZAP vote transport is a later stage.
class KeeperAppendStream
{
public:
    explicit KeeperAppendStream(KeeperServer & server_) : server(server_) {}

    /// Drive each request to single-node Quasar finality + commit, in order
    /// (routes through KeeperServer::putRequestBatch — the one commit primitive).
    void append(const KeeperRequestsForSessions & requests);

    bool is_abandoned() const { return false; }  /// single-node leader never abandons
    bool is_ready() const { return true; }
    bool is_idle() const { return true; }         /// synchronous: nothing left in flight

private:
    KeeperServer & server;
};

class KeeperServer
{
public:
    struct RespondingCounts
    {
        uint64_t learners = 0;
        uint64_t followers = 0;
        uint64_t synced_followers = 0;
        uint64_t synced_non_voting_followers = 0;
    };

private:
    friend class KeeperRequestDispatcher;
    friend class KeeperAppendStream;

    const int server_id;

    nuraft::ptr<KeeperStateManager> state_manager;

    nuraft::ptr<IKeeperStateMachine> state_machine;

    /// The leaderless Lux consensus engine (consensus2) — the single-node
    /// self-certifying coordinator that replaced nuraft::raft_server. Owns one BLS
    /// validator key; every write becomes a genuine 1-of-1 quorum certificate.
    std::unique_ptr<QuasarKeeperConsensus> consensus;

    /// Serializes the synchronous submit→vote→commit drive of the engine. Only the
    /// single active dispatch thread drives it, but the engine's wrapper state
    /// (next index, pending/ready maps) is not internally locked, so we guard it.
    mutable std::mutex consensus_mutex;

    // retained for API compatibility with callers that took the write lock during
    // recovery/reconfiguration; single-node has neither, but the mutex is harmless.
    mutable std::mutex server_write_mutex;

    std::mutex initialized_mutex;
    std::atomic<bool> initialized_flag = false;
    std::condition_variable initialized_cv;

    /// Single-node has no quorum to recover; always false.
    std::atomic_bool is_recovering = false;

    LoggerPtr log;

    KeeperContextPtr keeper_context;

    const bool create_snapshot_on_exit;
    const bool enable_reconfiguration;
    const bool is_standalone_keeper;

public:
    KeeperServer(
        const KeeperConfigurationPtr & server_config,
        const Poco::Util::AbstractConfiguration & config_,
        KeeperResponseCallback response_callback_,
        SnapshotsQueue & snapshots_queue_,
        KeeperContextPtr keeper_context_,
        KeeperSnapshotManagerS3 & snapshot_manager_s3,
        IKeeperStateMachine::CommitCallback commit_callback);

    /// Out-of-line so the unique_ptr<QuasarKeeperConsensus> member is destroyed where
    /// the engine type is complete (forward-declared in this header).
    ~KeeperServer();

    /// Load state machine from the latest snapshot and load log storage, then bring up
    /// the single-node Quasar coordinator (always-ready leader).
    void startup(const Poco::Util::AbstractConfiguration & config, bool enable_ipv6 = true);

    /// Open a single-node append stream (the synchronous successor to NuRaft's
    /// `client_req_stream`). Always non-null for a single-node leader.
    std::shared_ptr<KeeperAppendStream> openAppendStream(uint64_t timeout_ms);

    /// Execute read requests directly in the local state machine. Put response into responses queue.
    void putLocalReadRequests(const KeeperRequestsForSessions & requests);

    bool isRecovering() const { return is_recovering; }
    bool reconfigEnabled() const { return enable_reconfiguration; }

    /// Put batch of requests into Raft and get result of put. Responses will be sent separately
    /// through response_callback.
    RaftAppendResult putRequestBatch(const KeeperRequestsForSessions & requests);

    /// Return set of the non-active sessions
    std::vector<int64_t> getDeadSessions();

    nuraft::ptr<IKeeperStateMachine> getKeeperStateMachine() const { return state_machine; }

    void forceRecovery();

    bool isLeader() const;

    bool isFollower() const;

    bool isObserver() const;

    bool isLeaderAlive() const;

    bool isExceedingMemorySoftLimit() const;

    int64_t getLeaderID() const;

    Keeper4LWInfo getPartiallyFilled4LWInfo() const;

    /// @return responding learners/followers/synced followers; all zero when node is not leader
    RespondingCounts getRespondingCounts() const;

    /// Wait server initialization (see callbackFunc)
    void waitInit();

    /// Return true if KeeperServer initialized
    bool checkInit() const { return initialized_flag; }

    void shutdown();

    int getServerID() const { return server_id; }

    enum class ConfigUpdateState : uint8_t
    {
        Accepted,
        Declined,
        WaitBeforeChangingLeader
    };

    ConfigUpdateState applyConfigUpdate(
        const ClusterUpdateAction & action,
        bool last_command_was_leader_change = false);

    // TODO (myrrc) these functions should be removed once "reconfig" is stabilized
    void applyConfigUpdateWithReconfigDisabled(const ClusterUpdateAction& action);
    bool waitForConfigUpdateWithReconfigDisabled(const ClusterUpdateAction& action);
    ClusterUpdateActions getRaftConfigurationDiff(const Poco::Util::AbstractConfiguration & config);

    uint64_t createSnapshot();

    KeeperLogInfo getKeeperLogInfo();

    std::vector<KeeperClusterMemberInfo> getClusterMembersInfo() const;

    std::vector<KeeperChangelogStatus> getChangelogsStatus() const;

    bool requestLeader();

    void yieldLeadership();

    void recalculateStorageStats();

    std::optional<AuthenticationData> getAuthenticationData() const { return state_manager->getAuthenticationData(); }

    const KeeperContextPtr & getKeeperContext() const { return keeper_context; }
};

}
