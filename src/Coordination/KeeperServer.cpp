#include <Coordination/Defines.h>
#include <Coordination/KeeperServer.h>
#include <Coordination/QuasarKeeperConsensus.h>

#include "config.h"

#include <Coordination/CoordinationSettings.h>
#include <Coordination/KeeperLogStore.h>
#include <Coordination/KeeperSnapshotManagerS3.h>
#include <Coordination/KeeperStateMachine.h>
#include <Coordination/KeeperStateManager.h>
#include <Coordination/KeeperStorage.h>
#include <boost/algorithm/string.hpp>
#include <libnuraft/async.hxx>
#include <libnuraft/buffer.hxx>
#include <libnuraft/buffer_serializer.hxx>
#include <libnuraft/cluster_config.hxx>
#include <libnuraft/snapshot.hxx>
#include <Common/Exception.h>
#include <Common/MemoryTracker.h>
#include <Common/logger_useful.h>

#include <mutex>

namespace DB
{

namespace CoordinationSetting
{
    extern const CoordinationSettingsBool experimental_use_rocksdb;
    extern const CoordinationSettingsBool quorum_reads;
    extern const CoordinationSettingsUInt64 reserved_log_items;
    extern const CoordinationSettingsMilliseconds startup_timeout;
}

namespace ErrorCodes
{
    extern const int RAFT_ERROR;
    extern const int LOGICAL_ERROR;
    extern const int INVALID_CONFIG_PARAMETER;
}

namespace
{

std::string checkAndGetSuperdigest(const String & user_and_digest)
{
    if (user_and_digest.empty())
        return "";

    std::vector<std::string> scheme_and_id;
    boost::split(scheme_and_id, user_and_digest, [](char c) { return c == ':'; });
    if (scheme_and_id.size() != 2 || scheme_and_id[0] != "super")
        throw Exception(
            ErrorCodes::INVALID_CONFIG_PARAMETER, "Incorrect superdigest in keeper_server config. Must be 'super:base64string'");

    return user_and_digest;
}

}

KeeperServer::KeeperServer(
    const KeeperConfigurationPtr & server_config,
    const Poco::Util::AbstractConfiguration & config,
    KeeperResponseCallback response_callback_,
    SnapshotsQueue & snapshots_queue_,
    KeeperContextPtr keeper_context_,
    KeeperSnapshotManagerS3 & snapshot_manager_s3,
    IKeeperStateMachine::CommitCallback commit_callback)
    : server_id(server_config->server_id)
    , log(getLogger("KeeperServer"))
    , keeper_context{std::move(keeper_context_)}
    , create_snapshot_on_exit(config.getBool("keeper_server.create_snapshot_on_exit", true))
    , enable_reconfiguration(config.getBool("keeper_server.enable_reconfiguration", false))
    , is_standalone_keeper(server_config->standalone_keeper)
{
    const auto & coordination_settings = keeper_context->getFixedCoordinationSettings();
    if (coordination_settings[CoordinationSetting::quorum_reads])
        LOG_WARNING(log, "Quorum reads enabled, Keeper will work slower.");

#if USE_ROCKSDB
    if (coordination_settings[CoordinationSetting::experimental_use_rocksdb])
    {
        state_machine = nuraft::cs_new<KeeperStateMachine<KeeperRocksStorage>>(
            response_callback_,
            snapshots_queue_,
            keeper_context,
            config.getBool("keeper_server.upload_snapshot_on_exit", false) ? &snapshot_manager_s3 : nullptr,
            commit_callback,
            checkAndGetSuperdigest(server_config->super_digest));
        LOG_WARNING(log, "Use RocksDB as Keeper backend storage.");
    }
    else
#endif
        state_machine = nuraft::cs_new<KeeperStateMachine<KeeperMemoryStorage>>(
            response_callback_,
            snapshots_queue_,
            keeper_context,
            config.getBool("keeper_server.upload_snapshot_on_exit", false) ? &snapshot_manager_s3 : nullptr,
            commit_callback,
            checkAndGetSuperdigest(server_config->super_digest));

    state_manager = nuraft::cs_new<KeeperStateManager>(
        server_id,
        "keeper_server",
        "state",
        config,
        keeper_context);
}

KeeperServer::~KeeperServer() = default;

void KeeperServer::startup(const Poco::Util::AbstractConfiguration & /*config*/, bool /*enable_ipv6*/)
{
    state_machine->init();

    keeper_context->setLastCommitIndex(state_machine->last_commit_index());

    const auto & coordination_settings = keeper_context->getFixedCoordinationSettings();

    state_manager->loadLogStore(state_machine->last_commit_index(), coordination_settings[CoordinationSetting::reserved_log_items]);

    state_machine->setLogStore(state_manager->getLogStore().get());

    /// Single-node Quasar commits synchronously inside putRequestBatch, so there is
    /// never a window of preprocessed-but-uncommitted local logs that a leader
    /// election would have to drain. Mark preprocessing complete so commit() applies
    /// directly (it preprocesses-on-demand otherwise).
    keeper_context->setLocalLogsPreprocessed();

    /// Bring up the leaderless engine, continuing the log index from the last
    /// committed index recovered from snapshot/log. The node is its own sole
    /// validator (BLS key derived from server_id); see QuasarKeeperConsensus::singleNode.
    consensus = QuasarKeeperConsensus::singleNode(
        *state_machine,
        /*epoch=*/1,
        /*node_seed=*/static_cast<uint64_t>(server_id),
        /*start_index=*/state_machine->last_commit_index());

    /// A single-node leader is ready the instant it is up — no election, no quorum.
    {
        std::lock_guard lock(initialized_mutex);
        initialized_flag = true;
    }
    initialized_cv.notify_all();

    keeper_context->setServerState(KeeperContext::Phase::RUNNING);

    LOG_INFO(
        log,
        "Single-node Quasar coordinator started (server_id={}, last_committed={}). Engine: consensus2 "
        "1-of-1 BLS quorum certificate. NuRaft engine removed.",
        server_id,
        state_machine->last_commit_index());
}

void KeeperServer::shutdown()
{
    keeper_context->setServerState(KeeperContext::Phase::SHUTDOWN);
    state_manager->flushAndShutDownLogStore();
    state_machine->shutdownStorage();
    consensus.reset();
}

void KeeperServer::putLocalReadRequests(const KeeperRequestsForSessions & requests)
{
    for (const auto & request_for_session : requests)
    {
        if (!request_for_session.request->isReadRequest())
            throw Exception(ErrorCodes::LOGICAL_ERROR, "Cannot process non-read request locally");
    }
    state_machine->processReadRequests(requests);
}

RaftAppendResult KeeperServer::putRequestBatch(const KeeperRequestsForSessions & requests_for_sessions)
{
    /// The one commit primitive: drive every request through single-node Quasar to a
    /// genuine 1-of-1 quorum certificate and commit it — synchronously, in order.
    /// state_machine->commit fires the response callback and the dispatcher's commit
    /// callback inline, so by the time we return the batch is fully applied.
    uint64_t last_idx = 0;
    {
        std::lock_guard lock(consensus_mutex);
        last_idx = consensus->lastCommittedIndex();
        for (const auto & request_for_session : requests_for_sessions)
        {
            const auto result = consensus->appendLocal(request_for_session);
            last_idx = result.last_log_idx;
        }
    }

    /// Hand back the async-result shape the dispatchers read: accepted, OK, and a
    /// buffer carrying the committed index for the read-after-write barrier
    /// (keeper_context->waitCommittedUpto returns at once — already committed).
    auto buf = nuraft::buffer::alloc(sizeof(uint64_t));
    nuraft::buffer_serializer bs(buf);
    bs.put_u64(last_idx);
    return nuraft::cs_new<nuraft::cmd_result<nuraft::ptr<nuraft::buffer>>>(
        buf, /*accepted=*/true, nuraft::cmd_result_code::OK);
}

std::shared_ptr<KeeperAppendStream> KeeperServer::openAppendStream(uint64_t /*timeout_ms*/)
{
    /// A single-node leader is always available; the stream is a thin synchronous
    /// handle that routes appends straight to putRequestBatch.
    return std::make_shared<KeeperAppendStream>(*this);
}

bool KeeperServer::isLeader() const
{
    /// The sole node is always the leader.
    return true;
}

bool KeeperServer::isObserver() const
{
    /// The sole node is a voting member, never a non-voting learner.
    return false;
}

bool KeeperServer::isFollower() const
{
    return false;
}

bool KeeperServer::isLeaderAlive() const
{
    return true;
}

bool KeeperServer::isExceedingMemorySoftLimit() const
{
    if (!is_standalone_keeper)
        return false;
    Int64 mem_soft_limit = keeper_context->getKeeperMemorySoftLimit();
    return mem_soft_limit > 0 && std::max(total_memory_tracker.get(), total_memory_tracker.getRSS()) >= mem_soft_limit;
}

KeeperServer::RespondingCounts KeeperServer::getRespondingCounts() const
{
    /// No peers in a single-node deployment.
    return {};
}

void KeeperServer::waitInit()
{
    std::unique_lock lock(initialized_mutex);

    int64_t timeout = keeper_context->getCoordinationSettings()[CoordinationSetting::startup_timeout].totalMilliseconds();
    if (!initialized_cv.wait_for(lock, std::chrono::milliseconds(timeout), [&] { return initialized_flag.load(); }))
        LOG_WARNING(log, "Failed to wait for Keeper initialization in {}ms, will continue in background", timeout);
}

std::vector<int64_t> KeeperServer::getDeadSessions()
{
    return state_machine->getDeadSessions();
}

/// ── Reconfiguration ────────────────────────────────────────────────────────────
/// Dynamic cluster membership is a MULTI-NODE concern. A single-node Quasar keeper
/// has a fixed validator set of one; there is nothing to add, remove, or transfer.
/// These entry points are kept (the dispatcher's reconfig pipeline calls them) and
/// resolve to no-ops. Real reconfiguration arrives with the multi-node ZAP stage.

KeeperServer::ConfigUpdateState KeeperServer::applyConfigUpdate(
    const ClusterUpdateAction & /*action*/, bool /*last_command_was_leader_change*/)
{
    LOG_WARNING(log, "Cluster reconfiguration is not supported on a single-node Quasar keeper; ignoring update.");
    return ConfigUpdateState::Accepted;
}

ClusterUpdateActions KeeperServer::getRaftConfigurationDiff(const Poco::Util::AbstractConfiguration & /*config*/)
{
    /// No dynamic membership: the configuration never diffs for a single node.
    return {};
}

void KeeperServer::applyConfigUpdateWithReconfigDisabled(const ClusterUpdateAction & /*action*/)
{
    LOG_WARNING(log, "Cluster reconfiguration is not supported on a single-node Quasar keeper; ignoring update.");
}

bool KeeperServer::waitForConfigUpdateWithReconfigDisabled(const ClusterUpdateAction & /*action*/)
{
    return true;
}

Keeper4LWInfo KeeperServer::getPartiallyFilled4LWInfo() const
{
    Keeper4LWInfo result{};
    result.is_leader = true;
    result.is_observer = false;
    result.is_follower = false;
    result.has_leader = true;
    result.learner_count = 0;
    result.follower_count = 0;
    result.synced_follower_count = 0;
    result.synced_non_voting_follower_count = 0;
    result.is_standalone = true;
    result.is_exceeding_mem_soft_limit = isExceedingMemorySoftLimit();
    return result;
}

uint64_t KeeperServer::createSnapshot()
{
    std::lock_guard lock(consensus_mutex);
    uint64_t committed = consensus ? consensus->lastCommittedIndex() : state_machine->last_commit_index();
    if (committed == 0)
    {
        LOG_WARNING(log, "Nothing committed yet, skipping snapshot creation.");
        return 0;
    }

    auto cluster_config = state_machine->getClusterConfig();
    if (!cluster_config)
        cluster_config = nuraft::cs_new<nuraft::cluster_config>();

    /// term is meaningless without elections; bind it to 1 for the snapshot metadata.
    nuraft::snapshot snapshot(committed, /*last_log_term=*/1, cluster_config);
    nuraft::async_result<bool>::handler_type when_done
        = [](bool & /*ret*/, nuraft::ptr<std::exception> & /*e*/) {};
    state_machine->create_snapshot(snapshot, when_done);
    LOG_INFO(log, "Snapshot creation scheduled with last committed log index {}.", committed);
    return committed;
}

KeeperLogInfo KeeperServer::getKeeperLogInfo()
{
    KeeperLogInfo log_info;
    auto log_store = state_manager->load_log_store();
    if (log_store)
    {
        const auto & keeper_log_storage = static_cast<const KeeperLogStore &>(*log_store);
        keeper_log_storage.getKeeperLogInfo(log_info);
    }

    const uint64_t committed = consensus ? consensus->lastCommittedIndex() : state_machine->last_commit_index();
    log_info.last_committed_log_idx = committed;
    log_info.leader_committed_log_idx = committed;
    log_info.target_committed_log_idx = committed;
    if (auto snp = state_machine->last_snapshot())
        log_info.last_snapshot_idx = snp->get_last_log_idx();

    return log_info;
}

std::vector<KeeperChangelogStatus> KeeperServer::getChangelogsStatus() const
{
    auto log_store = state_manager->load_log_store();
    if (log_store)
        return static_cast<const KeeperLogStore &>(*log_store).getChangelogsStatus();
    return {};
}

bool KeeperServer::requestLeader()
{
    /// Already the leader.
    return true;
}

int64_t KeeperServer::getLeaderID() const
{
    /// Self is the leader.
    return server_id;
}

std::vector<KeeperClusterMemberInfo> KeeperServer::getClusterMembersInfo() const
{
    std::vector<KeeperClusterMemberInfo> result;
    const auto cluster_config = state_manager->getClusterConfig();
    if (!cluster_config)
        return result;

    const auto & servers = cluster_config->get_servers();
    result.reserve(servers.size());
    for (const auto & cfg : servers)
    {
        KeeperClusterMemberInfo info;
        info.server_id = cfg->get_id();
        info.endpoint = cfg->get_endpoint();
        info.is_observer = cfg->is_learner();
        info.priority = cfg->get_priority();
        info.is_leader = (cfg->get_id() == server_id);
        info.is_self = (cfg->get_id() == server_id);
        if (info.is_self)
            info.last_log_index = consensus ? consensus->lastCommittedIndex() : 0;
        result.push_back(std::move(info));
    }
    return result;
}

void KeeperServer::yieldLeadership()
{
    /// A single-node keeper cannot yield: there is no one to yield to.
}

void KeeperServer::forceRecovery()
{
    LOG_WARNING(log, "forceRecovery is a no-op for a single-node Quasar keeper (no quorum to recover).");
}

void KeeperServer::recalculateStorageStats()
{
    state_machine->recalculateStorageStats();
}

void KeeperAppendStream::append(const KeeperRequestsForSessions & requests)
{
    /// Synchronous single-node append: route straight to the one commit primitive.
    /// The commit + response/commit callbacks fire inline before this returns.
    server.putRequestBatch(requests);
}

}
