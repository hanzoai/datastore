#pragma once

#include "config.h"

#if USE_ZAP

#include <Server/IServer.h>
#include <Poco/Net/SocketAddress.h>
#include <base/types.h>
#include <atomic>
#include <memory>
#include <thread>

namespace Poco { class Logger; }

namespace DB
{

/// Native ZAP (Zero-Copy App Proto) query transport — the in-process replacement for the
/// removed gRPC server. Runs a KJ event loop on its own thread that accepts connections and
/// serves a zap-rpc bootstrap capability with promise pipelining.
///
/// This is the transport plumbing: it owns the port + event loop. The query service interface
/// (the .zap schema methods that dispatch to executeQuery and stream results) is layered on the
/// bootstrap capability — see ZapServer.cpp.
class ZapServer
{
public:
    ZapServer(IServer & server_, const Poco::Net::SocketAddress & address_);
    ~ZapServer();

    /// Starts the KJ event loop thread and begins listening.
    void start();
    /// Stops the event loop (cancels listen) and joins the thread.
    void stop();

    UInt16 portNumber() const { return address.port(); }
    size_t currentConnections() const { return current_connections.load(); }
    size_t currentThreads() const { return runtime_thread.joinable() ? 1 : 0; }

private:
    void run();

    IServer & server;
    Poco::Net::SocketAddress address;
    Poco::Logger * log;

    std::thread runtime_thread;
    std::atomic<bool> should_stop{false};
    std::atomic<size_t> current_connections{0};

    /// Opaque KJ state (event loop, listener, server) — defined in the .cpp to keep zap/kj
    /// headers out of this header (and out of every TU that includes it).
    struct Runtime;
    std::unique_ptr<Runtime> runtime;
};

}

#endif
