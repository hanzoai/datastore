/*
 * ZAPHandler.h — ZAP binary protocol handler for hanzo/datastore.
 *
 * Listens on port 9655 for ZAP connections and routes SQL queries
 * to the internal query pipeline.
 */
#pragma once

#include <atomic>
#include <thread>
#include <memory>
#include <string>

#include <Poco/Logger.h>
#include <Server/IServer.h>

namespace DB
{

class Context;

class ZAPHandler
{
public:
    ZAPHandler(IServer & server, int port = 9655);
    ~ZAPHandler();

    void start();
    void stop();

private:
    void listenerLoop();
    void handleConnection(int client_fd);
    std::string executeQuery(const std::string & sql);

    IServer & server;
    int port;
    int server_fd = -1;
    std::atomic<bool> running{false};
    std::thread listener_thread;
    Poco::Logger * log;
};

} // namespace DB
