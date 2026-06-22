#include <Server/ZapServer.h>

#if USE_ZAP

#include <Common/logger_useful.h>
#include <Common/Exception.h>

#include <chrono>

namespace DB
{

/// Opaque KJ state. Empty for the transport-plumbing scaffold; the KJ event loop, listener and
/// zap-rpc TwoPartyServer are layered here next (see ZapServer.h doc).
struct ZapServer::Runtime
{
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
    if (runtime_thread.joinable())
        runtime_thread.join();
}

void ZapServer::run()
{
    /// Transport-plumbing scaffold: the port is bound by the acceptor in Server.cpp; this thread
    /// will host the KJ event loop + zap-rpc TwoPartyServer (promise pipelining) serving the .zap
    /// query interface. Until that lands it parks so start/stop and the ProtocolServerAdapter
    /// lifecycle are exercised end to end.
        (void)server; /// retained for the query service (executeQuery dispatch) layered next
LOG_INFO(log, "ZAP server started on {} (native transport; query service pending)", address.toString());
    while (!should_stop.load())
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    LOG_INFO(log, "ZAP server stopped on {}", address.toString());
}

}

#endif
