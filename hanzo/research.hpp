// The C++ port of the Hanzo Research SDK — the ONE way a native producer (a kernel, a
// benchmark, the datastore/luxcpp stack) records and queries R&D evidence on the unified
// /v1/research plane (HIP-0512). It mirrors the Python reference verb-for-verb so every
// language emits byte-identical records into the one store.
//
//   #include "research.hpp"
//   namespace research = hanzo::research;
//
//   research::Client c;                                   // base/key/project from the env
//   auto k = c.experiment("kernel-perf", "matvec_q4k_f32_blk", "vulkan/6144x2048",
//                         {.metric = "ratio_vs_hand",
//                          .hypothesis = "the DSL f32-direct matvec beats the hand kernel",
//                          .predict    = "DSL/hand >= 1.0 cold at the dominant FFN shape"});
//   k.log("cold in-engine A/B, evo gfx1151, 3 runs, bit-exact 2.3e-6");
//   k.conclude(research::Verdict::Proven, "1.022x at 6144 rows", 1.022);   // git sha auto-stamped
//
// Zero-config provenance: the constructor reads git sha/branch/dirty, the commit messages
// since this experiment's last recorded run, the host, and the caller-supplied lib
// versions, and weaves them into the record's meta exactly like the Python SDK.
//
// kind is an OPEN string — benchmark, kernel-perf, training, ablation, policy-eval AND
// marketing-experiment, ad-test, growth-experiment. No kind enum; document, don't hardcode.
//
// Auth is the per-org key (Bearer). The key is read from HANZO_API_KEY, which a deployment
// populates from KMS (KMSSecret -> K8s Secret -> env); it is never hardcoded or logged.
#pragma once

#include <cstdint>
#include <string>
#include <utility>
#include <vector>

namespace hanzo::research {

// ── json ────────────────────────────────────────────────────────────────────────────
// A minimal ordered JSON value. Objects preserve insertion order and dump() matches
// Python's json.dumps default (", "/": " separators, ensure_ascii, float repr) so a C++
// record is byte-identical to the same record from the Python SDK. The record schema is
// small and closed, so a focused serializer is simpler than taking a JSON dependency —
// and it is the only way to guarantee that byte-identity.
namespace json {

class Value {
public:
    enum class Kind { Null, Bool, Int, Real, Str, Array, Object };

    Value() : kind_(Kind::Null) {}
    Value(bool b) : kind_(Kind::Bool), bool_(b) {}
    Value(int i) : kind_(Kind::Int), int_(i) {}
    Value(long i) : kind_(Kind::Int), int_(i) {}
    Value(long long i) : kind_(Kind::Int), int_(i) {}
    Value(double d) : kind_(Kind::Real), real_(d) {}
    Value(const char* s) : kind_(Kind::Str), str_(s) {}
    Value(std::string s) : kind_(Kind::Str), str_(std::move(s)) {}

    static Value object() { Value v; v.kind_ = Kind::Object; return v; }
    static Value array() { Value v; v.kind_ = Kind::Array; return v; }

    // Append a member (objects) / element (arrays); both preserve order. Chainable.
    Value& set(std::string key, Value val) { members_.emplace_back(std::move(key), std::move(val)); return *this; }
    Value& push(Value val) { elems_.push_back(std::move(val)); return *this; }

    Kind kind() const { return kind_; }
    std::string dump() const;

    // Reads: enough to walk a parsed response. A missing key / wrong type yields a Null
    // value / empty string, never a throw — a read never crashes a producer.
    const Value& operator[](const std::string& key) const;
    const std::vector<Value>& arr() const { return elems_; }
    std::string str() const { return kind_ == Kind::Str ? str_ : std::string(); }
    bool boolean() const { return kind_ == Kind::Bool && bool_; }

private:
    void write(std::string& out) const;  // recursive serializer backing dump()

    Kind kind_;
    bool bool_ = false;
    long long int_ = 0;
    double real_ = 0;
    std::string str_;
    std::vector<std::pair<std::string, Value>> members_;
    std::vector<Value> elems_;
};

// Parse a JSON document. On any malformed input returns a Null value (reads degrade, never
// throw); the writer path is the contract, the reader is best-effort.
Value parse(const std::string& text);

}  // namespace json

// ── provenance ──────────────────────────────────────────────────────────────────────
// Zero-config auto-capture of the run's environment. The caller supplies nothing; these
// read git and the host exactly like the Python provenance module.
namespace provenance {

struct Git {
    std::string sha;      // HEAD commit
    std::string branch;   // current branch
    bool dirty = false;   // working tree had uncommitted changes
};

// git sha/branch/dirty for the producing repo ("" fields when git is unavailable).
Git git(const std::string& repo);

// The commit-subject narrative — what changed since this experiment's last recorded run.
// `since` is the last run's sha (`<since>..HEAD`); empty falls back to the last `window`
// commits. `since` is validated to a hex object id before use, so a server-returned value
// can never inject a shell command through the underlying `git log`.
std::vector<std::string> commits(const std::string& repo, const std::string& since, int window);

std::string hostname();  // this box's hostname
std::string platform();  // uname sysname (e.g. "Linux", "Darwin")

// The git toplevel the caller runs in, auto-detected from `start` (default: the cwd).
std::string repo(const std::string& start);

}  // namespace provenance

// ── transport ───────────────────────────────────────────────────────────────────────
// The one HTTP seam. The record-serialization + provenance core is fully self-contained
// and needs no HTTP library; a deployment plugs in a transport. The production transport
// is libcurl (TLS to api.hanzo.ai), compiled in with -DHANZO_RESEARCH_CURL and available
// vendored at datastore/contrib/curl; a test or sidecar can inject its own.
struct Transport {
    struct Response {
        long status = 0;
        std::string body;
    };
    virtual ~Transport() = default;
    virtual Response send(const std::string& method,
                          const std::string& url,
                          const std::vector<std::string>& headers,
                          const std::string& body) = 0;
};

// A run's epistemic verdict — type-safe, so a refutation is a first-class result that
// cannot be mistyped. Distinct from execution status; set by Experiment::conclude.
enum class Verdict { Proven, Refuted, Inconclusive };

// One measured attempt's outcome (mirrors the Python `result` dict).
struct Result {
    std::string answer;
    bool correct = false;
    std::string response;
    std::string gold;
    std::string source = "hanzo-measured";
    std::string status = "complete";  // faulted/failed retain a negative result
};

// experiment() options (mirrors the Python kwargs). `doc` is "what this experiment is" —
// C++ has no docstring to auto-scrape, so the caller may supply it; the other narrative
// (commits, host, git) is captured with nothing asked of the caller.
struct Options {
    std::string metric = "accuracy";
    long n_total = 0;
    std::string note;
    std::string hypothesis;
    std::string predict;
    std::string doc;
};

// name -> version, insertion-ordered so lib_versions serializes identically across runs.
using Libs = std::vector<std::pair<std::string, std::string>>;

class Experiment;

// A configured research client. Base URL, per-org key, and project default from the
// environment (RESEARCH_BASE, HANZO_API_KEY, RESEARCH_PROJECT); the repo is auto-detected.
class Client {
public:
    explicit Client(std::string base = "",
                    std::string api_key = "",
                    std::string project = "",
                    std::string repo = "",
                    Libs libs = {},
                    Transport* transport = nullptr);

    // Get/create the experiment for (kind, subject, task) and return a handle. Provenance
    // and the since-last-run narrative are captured here, and the run is posted in-flight.
    Experiment experiment(const std::string& kind,
                          const std::string& subject,
                          const std::string& task,
                          const Options& opts = {});

    // Reads. query() returns the canonical experiments (the answered latest-run view);
    // totals() the headline aggregate. Both return parsed JSON.
    std::vector<json::Value> query(const std::string& project = "", const std::string& kind = "");
    json::Value totals(const std::string& project = "");

    // Low-level surface mirroring the contract (used by a bulk uploader). Idempotent by
    // content; returns the parsed cloud counts.
    json::Value ingest(std::vector<json::Value> experiments, std::vector<json::Value> attempts);
    json::Value artifact(json::Value art);
    json::Value grant(json::Value g);

    const std::string& repo() const { return repo_; }
    const std::string& project() const { return project_; }
    const Libs& libs() const { return libs_; }

private:
    friend class Experiment;

    std::string request(const std::string& method, const std::string& path, const std::string* body);
    std::vector<std::string> headers() const;
    Transport* transport();
    // The git sha of this experiment's last recorded run, for the since-narrative. Any
    // failure yields "" (the narrative then falls back to the recent window).
    std::string since(const std::string& id);

    std::string base_, key_, project_, repo_;
    Libs libs_;
    Transport* transport_;
};

// A handle to one run (kind:subject:task). record() files attempts; note() appends the
// running log; snapshot()/report() file diary artifacts; conclude()/finish() seal the run.
class Experiment {
public:
    Experiment(Client& c, std::string kind, std::string subject, std::string task, Options opts);

    // Append to the running log — the "what I saw" trail that travels into the record.
    // (`note` is the one-shot Options field; this accumulates the per-run log.) Chainable.
    Experiment& log(std::string text);

    // File one attempt (idempotent by content). Updates the answered counters unless the
    // attempt faulted/failed.
    json::Value record(const std::string& item, const std::string& model, const Result& result);

    // Seal the run with its epistemic verdict + the reasoning that earns it. A refutation
    // is recorded as clearly and durably as a proof. With no explicit value, the value is
    // computed from the recorded attempts.
    json::Value conclude(Verdict verdict, std::string because = "");
    json::Value conclude(Verdict verdict, std::string because, double value);

    // Diary artifacts — the SDK submits the bytes; the server content-addresses them.
    json::Value snapshot(const std::string& bytes, const std::string& run_id = "");
    json::Value report(const std::string& bytes, const std::string& run_id = "");

    // Seal the run. With no explicit value it is computed from the recorded attempts. A
    // stated hypothesis with no declared verdict defaults to Inconclusive — a finished run
    // never silently reads as a proof.
    json::Value finish();
    json::Value finish(double value);

    const std::string& id() const { return id_; }

private:
    json::Value post(const std::string& status, double value);
    json::Value artifact(const std::string& kind, const std::string& raw, const std::string& run_id);
    json::Value meta() const;

    Client& c_;
    std::string kind_, subject_, task_, metric_, id_;
    long n_total_;
    long ok_ = 0, n_ = 0;
    std::string hypothesis_, predict_, doc_, note_;
    std::string verdict_;  // ""|proven|refuted|inconclusive
    std::string because_;
    std::vector<std::string> log_;
    provenance::Git git_;
    std::vector<std::string> commits_;
    std::string hostname_, platform_;
};

}  // namespace hanzo::research
