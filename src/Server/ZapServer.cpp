#include <Server/ZapServer.h>

#if USE_ZAP

#include <Common/logger_useful.h>
#include <Common/Exception.h>

#include <kj/async.h>
#include <kj/async-io.h>
#include <kj/memory.h>
#include <zap/capability.h>
#include <zap/rpc-twoparty.h>

#include <condition_variable>
#include <mutex>

namespace DB
{

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
    (void)server; /// retained for the query service (executeQuery dispatch) layered next

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

        /// Null bootstrap for now — proves the zap-rpc handshake + pipelining transport. The .zap
        /// query interface (executeQuery dispatch, result streaming) is served as the bootstrap next.
        zap::TwoPartyServer rpc_server(zap::Capability::Client(nullptr));

        auto parsed = io.provider->getNetwork()
                          .parseAddress(address.host().toString(), address.port())
                          .wait(io.waitScope);
        auto listener = parsed->listen();

        LOG_INFO(log, "ZAP server listening on {} (zap-rpc, promise pipelining)", address.toString());

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
