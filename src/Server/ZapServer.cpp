#include <Server/ZapServer.h>

#if USE_ZAP

#include <Common/logger_useful.h>
#include <Common/Exception.h>
#include <Common/quoteString.h>
#include <IO/ReadBufferFromString.h>
#include <IO/WriteBufferFromString.h>
#include <IO/Progress.h>
#include <Interpreters/executeQuery.h>
#include <Interpreters/Session.h>
#include <Interpreters/Context.h>
#include <Interpreters/ClientInfo.h>
#include <base/types.h>

#include <kj/async.h>
#include <kj/async-io.h>
#include <kj/debug.h>
#include <kj/memory.h>
#include <zap/capability.h>
#include <zap/rpc-twoparty.h>

#include <Server/datastore.zap.h>

#include <condition_variable>
#include <mutex>
#include <string>

namespace DB
{

namespace
{

/// The bootstrap capability of the ZAP data plane. One shared instance serves every zap-rpc
/// connection on the ZAP port. Each call opens a fresh Session, authenticates through the same
/// AccessControl path as the HTTP/native interfaces, and dispatches to the in-process query engine
/// (Interpreters/executeQuery) — no separate protocol, no data copy beyond the message payload.
class DatastoreCapability final : public Zap::Datastore::Server
{
public:
    DatastoreCapability(IServer & server_, Poco::Net::SocketAddress address_)
        : server(server_), address(std::move(address_))
    {
    }

    kj::Promise<void> execQuery(ExecQueryContext context) override
    {
        auto params = context.getParams();
        const std::string sql(params.getSql().cStr(), params.getSql().size());
        const std::string format(params.getFormat().cStr(), params.getFormat().size());

        const std::string result = dispatch(/*database=*/ "", /*default_format=*/ format, sql, /*written=*/ nullptr);

        context.getResults().setResult(
            ::zap::Data::Reader(reinterpret_cast<const kj::byte *>(result.data()), result.size()));
        return kj::READY_NOW;
    }

    kj::Promise<void> insert(InsertContext context) override
    {
        auto params = context.getParams();
        const std::string database(params.getDatabase().cStr(), params.getDatabase().size());
        const std::string table(params.getTable().cStr(), params.getTable().size());
        const std::string format(params.getFormat().cStr(), params.getFormat().size());
        const auto rows = params.getRows();

        /// Reuse the SQL INSERT path so every engine, format and constraint behaves exactly as it
        /// does over HTTP/TCP: the FORMAT clause makes executeQuery consume the trailing bytes as data.
        std::string payload = "INSERT INTO " + backQuoteIfNeed(database) + "." + backQuoteIfNeed(table)
            + " FORMAT " + format + "\n";
        payload.append(reinterpret_cast<const char *>(rows.begin()), rows.size());

        UInt64 written = 0;
        dispatch(database, /*default_format=*/ "", payload, &written);

        context.getResults().setWritten(written);
        return kj::READY_NOW;
    }

private:
    /// Runs one statement synchronously and returns the formatted output (empty for statements with
    /// no result set). If `written` is non-null it receives the number of rows written (for INSERT).
    std::string dispatch(const std::string & database, const std::string & default_format,
                         const std::string & text, UInt64 * written)
    {
        Session session(server.context(), ClientInfo::Interface::TCP);
        /// Authenticate through the standard credentials path, exactly like an HTTP request that
        /// carries no auth headers: the 'default' user, subject to its configured AccessControl.
        session.authenticate("default", "", address);
        session.makeSessionContext();
        ContextMutablePtr context = session.makeQueryContext();

        if (!database.empty())
            context->setCurrentDatabase(database);
        if (!default_format.empty())
            context->setDefaultFormat(default_format);

        if (written != nullptr)
        {
            UInt64 * sink = written;
            context->setProgressCallback([sink](const Progress & progress)
            {
                *sink += progress.written_rows.load(std::memory_order_relaxed);
            });
        }

        ReadBufferFromString istr(text);
        WriteBufferFromOwnString ostr;
        try
        {
            executeQuery(istr, ostr, context, {});
        }
        catch (const Exception & e)
        {
            KJ_FAIL_REQUIRE(std::string(e.displayText()));
        }
        catch (const std::exception & e)
        {
            KJ_FAIL_REQUIRE(std::string(e.what()));
        }
        return ostr.str();
    }

    IServer & server;
    Poco::Net::SocketAddress address;
};

}

/// KJ event-loop state. KJ promises/fulfillers are thread-confined; the only safe cross-thread
/// signal is a CrossThreadPromiseFulfiller, created inside the loop thread and fulfilled from stop().
struct ZapServer::Runtime
{
    std::mutex mutex;
    std::condition_variable ready_cv;
    bool ready = false;
    kj::Own<kj::CrossThreadPromiseFulfiller<void>> stop_fulfiller;
};

ZapServer::ZapServer(IServer & server_, const Poco::Net::SocketAddress & address_)
    : server(server_)
    , address(address_)
    , log(&Poco::Logger::get("ZapServer"))
    , runtime(std::make_unique<Runtime>())
{
}

ZapServer::~ZapServer()
{
    try
    {
        stop();
    }
    catch (...)
    {
    }
}

void ZapServer::start()
{
    if (runtime_thread.joinable())
        return;
    should_stop.store(false);
    runtime_thread = std::thread([this] { run(); });
}

void ZapServer::stop()
{
    should_stop.store(true);
    if (!runtime_thread.joinable())
        return;

    /// Wait until run() has published its cross-thread fulfiller, then fulfill it to unwind the
    /// event loop. (The fulfiller is created on the loop thread but safe to fulfill from here.)
    {
        std::unique_lock<std::mutex> lock(runtime->mutex);
        runtime->ready_cv.wait(lock, [this] { return runtime->ready; });
        if (runtime->stop_fulfiller)
            runtime->stop_fulfiller->fulfill();
    }
    runtime_thread.join();
}

void ZapServer::run()
{
    try
    {
        auto io = kj::setupAsyncIo();

        auto paf = kj::newPromiseAndCrossThreadFulfiller<void>();
        {
            std::lock_guard<std::mutex> lock(runtime->mutex);
            runtime->stop_fulfiller = kj::mv(paf.fulfiller);
            runtime->ready = true;
        }
        runtime->ready_cv.notify_all();

        /// The Datastore capability is the bootstrap: clients call insert()/execQuery() on it directly,
        /// with promise pipelining. It dispatches to executeQuery on this loop thread (one statement at
        /// a time per loop); offloading long queries to a worker pool is the forward optimization.
        zap::TwoPartyServer rpc_server(kj::heap<DatastoreCapability>(server, address));

        const std::string host = address.host().toString();
        auto parsed = io.provider->getNetwork()
                          .parseAddress(kj::StringPtr(host.c_str()), address.port())
                          .wait(io.waitScope);
        auto listener = parsed->listen();

        LOG_INFO(log, "ZAP server listening on {} (zap-rpc, promise pipelining, Datastore bootstrap)", address.toString());

        /// listen() never resolves on its own; race it against the stop promise so stop() unwinds us.
        rpc_server.listen(*listener).exclusiveJoin(kj::mv(paf.promise)).wait(io.waitScope);

        LOG_INFO(log, "ZAP server stopped on {}", address.toString());
    }
    catch (const kj::Exception & e)
    {
        /// Publish readiness even on failure so stop() never deadlocks waiting for it.
        {
            std::lock_guard<std::mutex> lock(runtime->mutex);
            runtime->ready = true;
        }
        runtime->ready_cv.notify_all();
        LOG_ERROR(log, "ZAP server error on {}: {}", address.toString(), std::string(e.getDescription().cStr()));
    }
}

}

#endif
