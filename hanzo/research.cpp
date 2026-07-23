// Implementation of the Hanzo Research C++ client. See research.hpp for the API and the
// wire contract it mirrors (the Python hanzo-research SDK, byte-for-byte).
#include "research.hpp"

#include <array>
#include <charconv>
#include <cctype>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <stdexcept>

#include <sys/utsname.h>
#include <sys/wait.h>
#include <unistd.h>

#ifdef HANZO_RESEARCH_CURL
#include <curl/curl.h>
#endif

namespace hanzo::research {
namespace {

// ── process + string helpers ──────────────────────────────────────────────────────────

// Single-quote a string for /bin/sh so an embedded value can never break out of its
// argument (the git repo path and validated sha are the only interpolated values).
std::string shquote(const std::string& s) {
    std::string out = "'";
    for (char c : s) out += (c == '\'') ? std::string("'\\''") : std::string(1, c);
    out += "'";
    return out;
}

// Run a command, return its stdout trimmed both ends (mirrors Python's subprocess+.strip).
// A non-zero exit or spawn failure yields "" — a missing/erroring git is not fatal.
std::string capture(const std::string& cmd) {
    FILE* p = popen(cmd.c_str(), "r");
    if (!p) return "";
    std::string out;
    char buf[4096];
    size_t n;
    while ((n = std::fread(buf, 1, sizeof buf, p)) > 0) out.append(buf, n);
    int rc = pclose(p);
    if (rc == -1 || !WIFEXITED(rc) || WEXITSTATUS(rc) != 0) return "";
    size_t a = out.find_first_not_of(" \t\r\n");
    if (a == std::string::npos) return "";
    size_t b = out.find_last_not_of(" \t\r\n");
    return out.substr(a, b - a + 1);
}

std::string env(const char* name, const std::string& fallback) {
    const char* v = std::getenv(name);
    return (v && *v) ? std::string(v) : fallback;
}

// Strip control bytes so a value can never inject a header line (CR/LF) or a NUL. Applied
// to the key and project — the two values that become HTTP header content.
std::string oneline(const std::string& s) {
    std::string out;
    out.reserve(s.size());
    for (unsigned char c : s)
        if (c >= 0x20 && c != 0x7f) out += (char)c;
    return out;
}

// ── base64 (artifact content) ─────────────────────────────────────────────────────────
std::string base64(const std::string& in) {
    static const char* T = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string out;
    out.reserve((in.size() + 2) / 3 * 4);
    size_t i = 0;
    for (; i + 3 <= in.size(); i += 3) {
        uint32_t x = (uint8_t)in[i] << 16 | (uint8_t)in[i + 1] << 8 | (uint8_t)in[i + 2];
        out += T[(x >> 18) & 63];
        out += T[(x >> 12) & 63];
        out += T[(x >> 6) & 63];
        out += T[x & 63];
    }
    if (size_t rem = in.size() - i) {
        uint32_t x = (uint8_t)in[i] << 16 | (rem == 2 ? (uint8_t)in[i + 1] << 8 : 0);
        out += T[(x >> 18) & 63];
        out += T[(x >> 12) & 63];
        out += (rem == 2) ? T[(x >> 6) & 63] : '=';
        out += '=';
    }
    return out;
}

// ── sha256 (FIPS 180-4; the server re-hashes and rejects a mismatch) ──────────────────
std::string sha256hex(const std::string& msg) {
    auto ror = [](uint32_t x, int n) { return (x >> n) | (x << (32 - n)); };
    static const uint32_t K[64] = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2};
    uint32_t h[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                     0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};
    std::string m = msg;
    uint64_t bits = (uint64_t)m.size() * 8;
    m += (char)0x80;
    while (m.size() % 64 != 56) m += (char)0;
    for (int i = 7; i >= 0; --i) m += (char)((bits >> (i * 8)) & 0xff);
    for (size_t off = 0; off < m.size(); off += 64) {
        uint32_t w[64];
        for (int i = 0; i < 16; ++i)
            w[i] = (uint8_t)m[off + i * 4] << 24 | (uint8_t)m[off + i * 4 + 1] << 16 |
                   (uint8_t)m[off + i * 4 + 2] << 8 | (uint8_t)m[off + i * 4 + 3];
        for (int i = 16; i < 64; ++i) {
            uint32_t s0 = ror(w[i - 15], 7) ^ ror(w[i - 15], 18) ^ (w[i - 15] >> 3);
            uint32_t s1 = ror(w[i - 2], 17) ^ ror(w[i - 2], 19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16] + s0 + w[i - 7] + s1;
        }
        uint32_t a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
        for (int i = 0; i < 64; ++i) {
            uint32_t S1 = ror(e, 6) ^ ror(e, 11) ^ ror(e, 25);
            uint32_t ch = (e & f) ^ (~e & g);
            uint32_t t1 = hh + S1 + ch + K[i] + w[i];
            uint32_t S0 = ror(a, 2) ^ ror(a, 13) ^ ror(a, 22);
            uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
            uint32_t t2 = S0 + maj;
            hh = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
        }
        h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
    }
    static const char* HEX = "0123456789abcdef";
    std::string out;
    for (uint32_t v : h)
        for (int i = 7; i >= 0; --i) out += HEX[(v >> (i * 4)) & 0xf];
    return out;
}

// ── JSON string escaping (Python json.dumps ensure_ascii=True) ────────────────────────
void escape(std::string& out, const std::string& s) {
    out += '"';
    size_t i = 0, n = s.size();
    while (i < n) {
        unsigned char c = (unsigned char)s[i];
        if (c == '"') { out += "\\\""; ++i; }
        else if (c == '\\') { out += "\\\\"; ++i; }
        else if (c == '\b') { out += "\\b"; ++i; }
        else if (c == '\f') { out += "\\f"; ++i; }
        else if (c == '\n') { out += "\\n"; ++i; }
        else if (c == '\r') { out += "\\r"; ++i; }
        else if (c == '\t') { out += "\\t"; ++i; }
        else if (c < 0x20) { char b[8]; std::snprintf(b, sizeof b, "\\u%04x", c); out += b; ++i; }
        else if (c <= 0x7e) { out += (char)c; ++i; }
        else {
            // Non-printable-ASCII: decode the UTF-8 sequence to a code point and emit
            // \uXXXX (surrogate pair beyond the BMP), exactly like ensure_ascii.
            uint32_t cp;
            int extra;
            if (c == 0x7f) { cp = 0x7f; extra = 0; }
            else if ((c & 0xE0) == 0xC0) { cp = c & 0x1F; extra = 1; }
            else if ((c & 0xF0) == 0xE0) { cp = c & 0x0F; extra = 2; }
            else if ((c & 0xF8) == 0xF0) { cp = c & 0x07; extra = 3; }
            else { cp = 0xFFFD; extra = 0; }
            bool ok = true;
            for (int k = 0; k < extra; ++k) {
                unsigned char cc = (i + 1 + k < n) ? (unsigned char)s[i + 1 + k] : 0;
                if ((cc & 0xC0) != 0x80) { ok = false; break; }
                cp = (cp << 6) | (cc & 0x3F);
            }
            i += ok ? (extra + 1) : 1;
            if (!ok) cp = 0xFFFD;
            char b[16];
            if (cp <= 0xFFFF) { std::snprintf(b, sizeof b, "\\u%04x", cp); out += b; }
            else {
                cp -= 0x10000;
                std::snprintf(b, sizeof b, "\\u%04x\\u%04x", 0xD800 + (cp >> 10), 0xDC00 + (cp & 0x3FF));
                out += b;
            }
        }
    }
    out += '"';
}

void writeReal(std::string& out, double d) {
    char buf[32];
    auto r = std::to_chars(buf, buf + sizeof buf, d);
    std::string s(buf, r.ptr);
    if (s.find_first_of(".eEnN") == std::string::npos) s += ".0";  // a Python float always shows a point
    out += s;
}

// ── percent-encoding for query params (Python urllib.parse.quote, safe='/') ───────────
std::string quote(const std::string& s) {
    static const char* HEX = "0123456789ABCDEF";
    std::string out;
    for (unsigned char c : s) {
        if (std::isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~' || c == '/') out += (char)c;
        else { out += '%'; out += HEX[c >> 4]; out += HEX[c & 0xf]; }
    }
    return out;
}

}  // namespace

// ── json::Value ───────────────────────────────────────────────────────────────────────
namespace json {

void Value::write(std::string& out) const {
    switch (kind_) {
        case Kind::Null: out += "null"; break;
        case Kind::Bool: out += bool_ ? "true" : "false"; break;
        case Kind::Int: out += std::to_string(int_); break;
        case Kind::Real: writeReal(out, real_); break;
        case Kind::Str: escape(out, str_); break;
        case Kind::Array:
            out += '[';
            for (size_t i = 0; i < elems_.size(); ++i) { if (i) out += ", "; elems_[i].write(out); }
            out += ']';
            break;
        case Kind::Object:
            out += '{';
            for (size_t i = 0; i < members_.size(); ++i) {
                if (i) out += ", ";
                escape(out, members_[i].first);
                out += ": ";
                members_[i].second.write(out);
            }
            out += '}';
            break;
    }
}

std::string Value::dump() const {
    std::string out;
    write(out);
    return out;
}

const Value& Value::operator[](const std::string& key) const {
    static const Value null;
    for (const auto& m : members_)
        if (m.first == key) return m.second;
    return null;
}

// A compact recursive-descent parser. Reads are best-effort: any malformed input returns
// Null rather than throwing, so a producer's read never crashes it.
namespace {
struct Parser {
    const std::string& s;
    size_t i = 0;
    explicit Parser(const std::string& t) : s(t) {}

    void ws() { while (i < s.size() && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r')) ++i; }
    bool eat(char c) { ws(); if (i < s.size() && s[i] == c) { ++i; return true; } return false; }

    Value value() {
        ws();
        if (i >= s.size()) return Value();
        char c = s[i];
        if (c == '{') return object();
        if (c == '[') return array();
        if (c == '"') return Value(string());
        if (c == 't') { i += 4; return Value(true); }
        if (c == 'f') { i += 5; return Value(false); }
        if (c == 'n') { i += 4; return Value(); }
        return number();
    }

    Value object() {
        Value o = Value::object();
        eat('{');
        ws();
        if (eat('}')) return o;
        do {
            ws();
            if (i >= s.size() || s[i] != '"') break;
            std::string k = string();
            eat(':');
            o.set(std::move(k), value());
        } while (eat(','));
        eat('}');
        return o;
    }

    Value array() {
        Value a = Value::array();
        eat('[');
        ws();
        if (eat(']')) return a;
        do { a.push(value()); } while (eat(','));
        eat(']');
        return a;
    }

    std::string string() {
        std::string out;
        ++i;  // opening quote
        while (i < s.size()) {
            char c = s[i++];
            if (c == '"') break;
            if (c != '\\') { out += c; continue; }
            if (i >= s.size()) break;
            char e = s[i++];
            switch (e) {
                case '"': out += '"'; break;
                case '\\': out += '\\'; break;
                case '/': out += '/'; break;
                case 'b': out += '\b'; break;
                case 'f': out += '\f'; break;
                case 'n': out += '\n'; break;
                case 'r': out += '\r'; break;
                case 't': out += '\t'; break;
                case 'u': {
                    uint32_t cp = hex4();
                    if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < s.size() && s[i] == '\\' && s[i + 1] == 'u') {
                        i += 2;
                        uint32_t lo = hex4();
                        cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
                    }
                    encodeUtf8(out, cp);
                    break;
                }
                default: out += e; break;
            }
        }
        return out;
    }

    uint32_t hex4() {
        uint32_t v = 0;
        for (int k = 0; k < 4 && i < s.size(); ++k) {
            char c = s[i++];
            v <<= 4;
            if (c >= '0' && c <= '9') v |= c - '0';
            else if (c >= 'a' && c <= 'f') v |= c - 'a' + 10;
            else if (c >= 'A' && c <= 'F') v |= c - 'A' + 10;
        }
        return v;
    }

    static void encodeUtf8(std::string& out, uint32_t cp) {
        if (cp <= 0x7f) out += (char)cp;
        else if (cp <= 0x7ff) { out += (char)(0xC0 | (cp >> 6)); out += (char)(0x80 | (cp & 0x3F)); }
        else if (cp <= 0xffff) {
            out += (char)(0xE0 | (cp >> 12));
            out += (char)(0x80 | ((cp >> 6) & 0x3F));
            out += (char)(0x80 | (cp & 0x3F));
        } else {
            out += (char)(0xF0 | (cp >> 18));
            out += (char)(0x80 | ((cp >> 12) & 0x3F));
            out += (char)(0x80 | ((cp >> 6) & 0x3F));
            out += (char)(0x80 | (cp & 0x3F));
        }
    }

    Value number() {
        size_t start = i;
        bool real = false;
        while (i < s.size()) {
            char c = s[i];
            if (c == '-' || c == '+' || (c >= '0' && c <= '9')) { ++i; continue; }
            if (c == '.' || c == 'e' || c == 'E') { real = true; ++i; continue; }
            break;
        }
        std::string tok = s.substr(start, i - start);
        if (tok.empty()) return Value();
        if (real) { try { return Value(std::stod(tok)); } catch (...) { return Value(); } }
        try { return Value((long long)std::stoll(tok)); } catch (...) { return Value(); }
    }
};
}  // namespace

Value parse(const std::string& text) {
    if (text.empty()) return Value();
    Parser p(text);
    return p.value();
}

}  // namespace json

// ── provenance ────────────────────────────────────────────────────────────────────────
namespace provenance {

Git git(const std::string& repo) {
    std::string base = "git -C " + shquote(repo) + " ";
    Git g;
    g.sha = capture(base + "rev-parse HEAD 2>/dev/null");
    g.branch = capture(base + "rev-parse --abbrev-ref HEAD 2>/dev/null");
    g.dirty = !capture(base + "status --porcelain 2>/dev/null").empty();
    return g;
}

std::vector<std::string> commits(const std::string& repo, const std::string& since, int window) {
    std::string base = "git -C " + shquote(repo) + " ";
    // A git object id is hex only; reject anything else so a value that reached us from the
    // network can never inject a command through the shell, then fall back to the window.
    bool hexok = !since.empty() && since.size() <= 64 &&
                 since.find_first_not_of("0123456789abcdefABCDEF") == std::string::npos;
    std::string raw = hexok
        ? capture(base + "log " + since + "..HEAD --format=%s 2>/dev/null")
        : capture(base + "log -" + std::to_string(window) + " --format=%s 2>/dev/null");
    std::vector<std::string> out;
    size_t start = 0;
    while (start <= raw.size()) {
        size_t nl = raw.find('\n', start);
        std::string line = raw.substr(start, nl == std::string::npos ? std::string::npos : nl - start);
        if (line.find_first_not_of(" \t\r") != std::string::npos) out.push_back(line);
        if (nl == std::string::npos) break;
        start = nl + 1;
    }
    return out;
}

std::string hostname() {
    char b[256];
    if (gethostname(b, sizeof b) == 0) { b[sizeof b - 1] = 0; return std::string(b); }
    return "";
}

std::string platform() {
    struct utsname u;
    if (uname(&u) == 0) return std::string(u.sysname);
    return "";
}

std::string repo(const std::string& start) {
    std::string dir = start;
    if (dir.empty()) {
        char b[4096];
        if (getcwd(b, sizeof b)) dir = b;
    }
    std::string top = capture("git -C " + shquote(dir) + " rev-parse --show-toplevel 2>/dev/null");
    return top.empty() ? dir : top;
}

}  // namespace provenance

// ── transport ─────────────────────────────────────────────────────────────────────────
namespace {

#ifdef HANZO_RESEARCH_CURL
// The production transport: libcurl handles TLS to api.hanzo.ai. Vendored at
// datastore/contrib/curl; link with -DHANZO_RESEARCH_CURL and CURL::libcurl.
class Curl : public Transport {
public:
    Curl() { curl_global_init(CURL_GLOBAL_DEFAULT); }
    ~Curl() override { curl_global_cleanup(); }

    Response send(const std::string& method, const std::string& url,
                  const std::vector<std::string>& headers, const std::string& body) override {
        CURL* h = curl_easy_init();
        if (!h) throw std::runtime_error("hanzo::research: curl_easy_init failed");
        Response r;
        curl_slist* hs = nullptr;
        for (const auto& x : headers) hs = curl_slist_append(hs, x.c_str());
        curl_easy_setopt(h, CURLOPT_URL, url.c_str());
        curl_easy_setopt(h, CURLOPT_HTTPHEADER, hs);
        curl_easy_setopt(h, CURLOPT_CUSTOMREQUEST, method.c_str());
        if (method != "GET") {
            curl_easy_setopt(h, CURLOPT_POSTFIELDS, body.c_str());
            curl_easy_setopt(h, CURLOPT_POSTFIELDSIZE, (long)body.size());
        }
        curl_easy_setopt(h, CURLOPT_WRITEFUNCTION, &Curl::write);
        curl_easy_setopt(h, CURLOPT_WRITEDATA, &r.body);
        curl_easy_setopt(h, CURLOPT_TIMEOUT, 120L);
        curl_easy_setopt(h, CURLOPT_FOLLOWLOCATION, 0L);
        CURLcode rc = curl_easy_perform(h);
        if (rc == CURLE_OK) curl_easy_getinfo(h, CURLINFO_RESPONSE_CODE, &r.status);
        curl_slist_free_all(hs);
        curl_easy_cleanup(h);
        if (rc != CURLE_OK) throw std::runtime_error(std::string("hanzo::research: transport: ") + curl_easy_strerror(rc));
        return r;
    }

private:
    static size_t write(char* p, size_t sz, size_t n, void* ud) {
        static_cast<std::string*>(ud)->append(p, sz * n);
        return sz * n;
    }
};
#endif

}  // namespace

// ── Client ────────────────────────────────────────────────────────────────────────────
Client::Client(std::string base, std::string api_key, std::string project, std::string repo,
               Libs libs, Transport* transport)
    : libs_(std::move(libs)), transport_(transport) {
    base_ = base.empty() ? env("RESEARCH_BASE", "https://api.hanzo.ai") : base;
    while (!base_.empty() && base_.back() == '/') base_.pop_back();
    key_ = oneline(api_key.empty() ? env("HANZO_API_KEY", "") : api_key);
    project_ = oneline(project.empty() ? env("RESEARCH_PROJECT", "default") : project);
    repo_ = repo.empty() ? provenance::repo("") : repo;
}

Transport* Client::transport() {
    if (transport_) return transport_;
#ifdef HANZO_RESEARCH_CURL
    static Curl curl;
    return &curl;
#else
    throw std::runtime_error(
        "hanzo::research: no HTTP transport compiled. Build with -DHANZO_RESEARCH_CURL and "
        "link libcurl (vendored at datastore/contrib/curl), or inject a Transport.");
#endif
}

std::vector<std::string> Client::headers() const {
    // Auth is ONLY the per-org key; the gateway mints the validated principal (org + user)
    // from it. The client never sends X-Org-Id/X-User-Id — that is a cross-tenant forge the
    // gateway strips anyway. The key is KMS-sourced via the environment, never hardcoded.
    std::vector<std::string> h = {"Content-Type: application/json", "X-Project-Id: " + project_};
    if (!key_.empty()) h.push_back("Authorization: Bearer " + key_);
    return h;
}

std::string Client::request(const std::string& method, const std::string& path, const std::string* body) {
    auto r = transport()->send(method, base_ + path, headers(), body ? *body : std::string());
    if (r.status < 200 || r.status >= 300)
        throw std::runtime_error("hanzo::research: HTTP " + std::to_string(r.status) + " " + r.body);
    return r.body;
}

json::Value Client::ingest(std::vector<json::Value> experiments, std::vector<json::Value> attempts) {
    json::Value exps = json::Value::array();
    for (auto& e : experiments) exps.push(std::move(e));
    json::Value atts = json::Value::array();
    for (auto& a : attempts) atts.push(std::move(a));
    json::Value body = json::Value::object();
    body.set("experiments", std::move(exps)).set("attempts", std::move(atts));
    std::string s = body.dump();
    return json::parse(request("POST", "/v1/research/experiments", &s));
}

json::Value Client::artifact(json::Value art) {
    std::string s = art.dump();
    return json::parse(request("POST", "/v1/research/artifacts", &s));
}

json::Value Client::grant(json::Value g) {
    std::string s = g.dump();
    return json::parse(request("POST", "/v1/research/grants", &s));
}

std::vector<json::Value> Client::query(const std::string& project, const std::string& kind) {
    std::string path = "/v1/research/experiments";
    std::vector<std::string> q;
    std::string p = project.empty() ? project_ : project;
    if (!p.empty()) q.push_back("project=" + quote(p));
    if (!kind.empty()) q.push_back("kind=" + quote(kind));
    if (!q.empty()) {
        path += "?";
        for (size_t i = 0; i < q.size(); ++i) { if (i) path += "&"; path += q[i]; }
    }
    json::Value out = json::parse(request("GET", path, nullptr));
    return out["data"].arr();
}

json::Value Client::totals(const std::string& project) {
    std::string path = "/v1/research/totals";
    if (!project.empty()) path += "?project=" + quote(project);
    return json::parse(request("GET", path, nullptr));
}

std::string Client::since(const std::string& id) {
    try {
        for (const auto& e : query())
            if (e["id"].str() == id) return e["git_sha"].str();
    } catch (...) {
    }
    return "";
}

Experiment Client::experiment(const std::string& kind, const std::string& subject,
                              const std::string& task, const Options& opts) {
    return Experiment(*this, kind, subject, task, opts);
}

// ── Experiment ────────────────────────────────────────────────────────────────────────
namespace {
const char* word(Verdict v) {
    switch (v) {
        case Verdict::Proven: return "proven";
        case Verdict::Refuted: return "refuted";
        case Verdict::Inconclusive: return "inconclusive";
    }
    return "inconclusive";
}
json::Value strings(const std::vector<std::string>& v) {
    json::Value a = json::Value::array();
    for (const auto& s : v) a.push(s);
    return a;
}
}  // namespace

Experiment::Experiment(Client& c, std::string kind, std::string subject, std::string task, Options opts)
    : c_(c),
      kind_(std::move(kind)),
      subject_(std::move(subject)),
      task_(std::move(task)),
      metric_(std::move(opts.metric)),
      n_total_(opts.n_total),
      hypothesis_(std::move(opts.hypothesis)),
      predict_(std::move(opts.predict)),
      doc_(std::move(opts.doc)),
      note_(std::move(opts.note)) {
    id_ = kind_ + ":" + subject_ + ":" + task_;
    git_ = provenance::git(c_.repo());
    hostname_ = provenance::hostname();
    platform_ = provenance::platform();
    // The narrative since this experiment's last recorded run (falls back to the window).
    commits_ = provenance::commits(c_.repo(), c_.since(id_), 10);
    // Post the run in-flight so the ops board sees it immediately.
    post("running", 0.0);
}

Experiment& Experiment::log(std::string text) {
    log_.push_back(std::move(text));
    return *this;
}

json::Value Experiment::meta() const {
    json::Value host = json::Value::object();
    host.set("hostname", hostname_).set("platform", platform_);
    json::Value m = json::Value::object();
    m.set("doc", doc_)
        .set("commits", strings(commits_))
        .set("note", note_)
        .set("host", std::move(host))
        .set("hypothesis", hypothesis_)
        .set("predict", predict_)
        .set("verdict", verdict_)
        .set("because", because_)
        .set("log", strings(log_));
    return m;
}

json::Value Experiment::post(const std::string& status, double value) {
    json::Value libs = json::Value::object();
    for (const auto& kv : c_.libs()) libs.set(kv.first, kv.second);
    json::Value e = json::Value::object();
    e.set("id", id_)
        .set("kind", kind_)
        .set("subject", subject_)
        .set("task", task_)
        .set("metric", metric_)
        .set("value", value)
        .set("n", (long long)n_)
        .set("n_total", (long long)n_total_)
        .set("status", status)
        .set("git_sha", git_.sha)
        .set("git_branch", git_.branch)
        .set("git_dirty", git_.dirty)
        .set("lib_versions", std::move(libs))
        .set("meta", meta());
    std::vector<json::Value> one;
    one.push_back(std::move(e));
    return c_.ingest(std::move(one), {});
}

json::Value Experiment::record(const std::string& item, const std::string& model, const Result& result) {
    json::Value a = json::Value::object();
    a.set("benchmark", task_)
        .set("item", item)
        .set("model", model)
        .set("answer", result.answer)
        .set("correct", result.correct)
        .set("response", result.response)
        .set("gold", result.gold)
        .set("source", result.source)
        .set("status", result.status);
    if (result.status != "faulted" && result.status != "failed") {
        ++n_;
        if (result.correct) ++ok_;
    }
    std::vector<json::Value> one;
    one.push_back(std::move(a));
    return c_.ingest({}, std::move(one));
}

json::Value Experiment::artifact(const std::string& kind, const std::string& raw, const std::string& run_id) {
    json::Value libs = json::Value::object();
    for (const auto& kv : c_.libs()) libs.set(kv.first, kv.second);
    json::Value a = json::Value::object();
    a.set("content", base64(raw))
        .set("sha256", sha256hex(raw))
        .set("kind", kind)
        .set("run_id", run_id.empty() ? id_ : run_id)
        .set("git_sha", git_.sha)
        .set("git_branch", git_.branch)
        .set("git_dirty", git_.dirty)
        .set("lib_versions", std::move(libs));
    return c_.artifact(std::move(a));
}

json::Value Experiment::snapshot(const std::string& bytes, const std::string& run_id) {
    return artifact("snapshot", bytes, run_id);
}

json::Value Experiment::report(const std::string& bytes, const std::string& run_id) {
    return artifact("report", bytes, run_id);
}

json::Value Experiment::conclude(Verdict verdict, std::string because) {
    verdict_ = word(verdict);
    because_ = std::move(because);
    return finish();
}

json::Value Experiment::conclude(Verdict verdict, std::string because, double value) {
    verdict_ = word(verdict);
    because_ = std::move(because);
    return finish(value);
}

json::Value Experiment::finish() {
    // Default headline = answered accuracy %, rounded to 2 places (counts are non-negative).
    double value = n_ ? std::round(100.0 * ok_ / n_ * 100.0) / 100.0 : 0.0;
    return finish(value);
}

json::Value Experiment::finish(double value) {
    // A stated hypothesis with no declared verdict finishes Inconclusive — never a silent proof.
    if (!hypothesis_.empty() && verdict_.empty()) verdict_ = "inconclusive";
    return post("complete", value);
}

}  // namespace hanzo::research
