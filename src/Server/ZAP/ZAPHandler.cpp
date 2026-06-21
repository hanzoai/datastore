/*
 * ZAPHandler.cpp — ZAP binary protocol handler for hanzo/datastore.
 *
 * Makes hanzo/datastore speak ZAP natively on port 9655.
 * Receives SQL queries via ZAP binary messages and executes them
 * through the internal query pipeline.
 */
#include "ZAPHandler.h"
#include "ZAPProtocol.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <cerrno>
#include <cstring>
#include <string>

#include <Poco/Logger.h>
#include <Common/logger_useful.h>

#include <Interpreters/executeQuery.h>
#include <Interpreters/Context.h>
#include <IO/ReadBufferFromString.h>
#include <IO/WriteBufferFromOwnString.h>
#include <Common/CurrentThread.h>

namespace DB
{

ZAPHandler::ZAPHandler(IServer & server_, int port_)
    : server(server_)
    , port(port_)
    , log(&Poco::Logger::get("ZAPHandler"))
{
}

ZAPHandler::~ZAPHandler()
{
    stop();
}

void ZAPHandler::start()
{
    running = true;
    listener_thread = std::thread([this] { listenerLoop(); });
    LOG_INFO(log, "ZAP handler started on port {}", port);
}

void ZAPHandler::stop()
{
    running = false;
    if (server_fd >= 0)
    {
        shutdown(server_fd, SHUT_RDWR);
        close(server_fd);
        server_fd = -1;
    }
    if (listener_thread.joinable())
        listener_thread.join();
    LOG_INFO(log, "ZAP handler stopped");
}

void ZAPHandler::listenerLoop()
{
    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0)
    {
        LOG_ERROR(log, "ZAP: socket() failed: {}", strerror(errno));
        return;
    }

    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(port);

    if (bind(server_fd, reinterpret_cast<struct sockaddr *>(&addr), sizeof(addr)) < 0)
    {
        LOG_ERROR(log, "ZAP: bind() port {} failed: {}", port, strerror(errno));
        close(server_fd);
        server_fd = -1;
        return;
    }

    listen(server_fd, 32);
    LOG_INFO(log, "ZAP: listening on port {}", port);

    while (running)
    {
        int client_fd = accept(server_fd, nullptr, nullptr);
        if (client_fd < 0)
        {
            if (errno == EINTR) continue;
            if (!running) break;
            LOG_WARNING(log, "ZAP: accept() failed: {}", strerror(errno));
            continue;
        }

        // Handle connection (single-threaded per-connection)
        handleConnection(client_fd);
        close(client_fd);
    }
}

void ZAPHandler::handleConnection(int client_fd)
{
    uint8_t buf[65536];
    ssize_t n = recv(client_fd, buf, sizeof(buf), 0);
    if (n <= 0) return;

    ZAP::Header hdr;
    if (!hdr.parse(buf, static_cast<size_t>(n)))
    {
        std::string err = R"({"error":"invalid ZAP header"})";
        ZAP::ResponseBuilder rb;
        auto resp = rb.build(400, err);
        send(client_fd, resp.data(), resp.size(), 0);
        return;
    }

    auto path = ZAP::readText(buf, n, hdr.root_offset, ZAP::FIELD_PATH);
    auto body = ZAP::readBytes(buf, n, hdr.root_offset, ZAP::FIELD_BODY);

    LOG_DEBUG(log, "ZAP: msg_type={} path={} body_len={}", hdr.msg_type, path, body.size());

    std::string result;
    uint32_t status = 200;

    if (path == "/query" || path == "/exec")
    {
        // Body contains SQL (or JSON with "sql" field)
        std::string sql(body);
        try
        {
            result = executeQuery(sql);
        }
        catch (const std::exception & e)
        {
            result = std::string(R"({"error":")") + e.what() + "\"}";
            status = 500;
        }
    }
    else
    {
        result = R"({"error":"unknown path"})";
        status = 400;
    }

    ZAP::ResponseBuilder rb;
    auto resp = rb.build(status, result);
    send(client_fd, resp.data(), resp.size(), 0);
}

std::string ZAPHandler::executeQuery(const std::string & raw_body)
{
    /* Body may be raw SQL or JSON: {"sql":"SELECT ...","format":"JSON"} */
    std::string sql = raw_body;
    std::string format = "JSON";

    if (!raw_body.empty() && raw_body[0] == '{')
    {
        /* Minimal JSON extraction for "sql" and optional "format" fields */
        auto extract = [&](const std::string & key) -> std::string {
            std::string search = "\"" + key + "\"";
            auto pos = raw_body.find(search);
            if (pos == std::string::npos) return {};
            pos = raw_body.find('"', pos + search.size() + 1);
            if (pos == std::string::npos) return {};
            auto end = raw_body.find('"', pos + 1);
            if (end == std::string::npos) return {};
            return raw_body.substr(pos + 1, end - pos - 1);
        };

        auto sql_val = extract("sql");
        if (!sql_val.empty())
            sql = sql_val;

        auto fmt_val = extract("format");
        if (!fmt_val.empty())
            format = fmt_val;
    }

    if (sql.empty())
        throw std::runtime_error("empty query");

    /* Create a mutable query context from the server global context */
    auto context = Context::createCopy(server.context());
    context->makeQueryContext();
    context->setDefaultFormat(format);

    auto & client_info = context->getClientInfo();
    client_info.interface = ClientInfo::Interface::TCP;
    client_info.query_kind = ClientInfo::QueryKind::INITIAL_QUERY;

    ReadBufferFromString in(sql);
    WriteBufferFromOwnString out;

    DB::executeQuery(in, out, false /* allow_into_outfile */, context, {});
    out.finalize();

    return out.str();
}

} // namespace DB
