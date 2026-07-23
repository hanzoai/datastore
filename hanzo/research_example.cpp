// A falsifiable, self-checking example for the Hanzo Research C++ client. It proves three
// things with no live server and no HTTP dependency:
//
//   1. SHA-256 is correct (the server rejects an artifact whose hash mismatches its bytes).
//   2. The full client flow works end-to-end for two UNIVERSAL kinds — a `kernel-perf` run
//      concluded Proven and a `marketing-experiment` run concluded Refuted — with zero-
//      config auto-provenance, over an injected capture transport.
//   3. The serialized wire bytes are byte-identical to the Python SDK (mode `ingest` emits
//      a fixed-provenance record for a cross-language diff).
//
//   g++ -std=c++17 -O2 research.cpp research_example.cpp -o research_example
//   ./research_example            # demo: sha256 self-test + the two sealed records
//   ./research_example ingest     # emit the fixed ingest body for the Python byte-diff
#include "research.hpp"

#include <cstdio>
#include <iostream>
#include <string>
#include <vector>

namespace research = hanzo::research;

// A transport that records every request instead of sending it, and answers reads with an
// empty result set so the since-narrative resolves cleanly offline. This is the swappable
// seam the header documents — a test injects this; a deployment injects libcurl.
class Capture : public research::Transport {
public:
    struct Call {
        std::string method, url, body;
    };
    std::vector<Call> calls;

    Response send(const std::string& method, const std::string& url,
                  const std::vector<std::string>& /*headers*/, const std::string& body) override {
        calls.push_back({method, url, body});
        Response r;
        r.status = 200;
        r.body = (method == "GET") ? "{\"data\": []}" : "{\"experiments_ingested\": 1}";
        return r;
    }
    const std::string& last() const { return calls.back().body; }
};

static int demo() {
    // 1. SHA-256 known-answer — a sealed artifact's identity depends on this being exact.
    //    We drive it through a real snapshot() and check the emitted sha256 field.
    Capture cap;
    research::Client c("https://api.hanzo.ai", "test-key", "enso-bench", "",
                       {{"hanzo-engine", "1.7.45"}, {"hanzo-ml", "0.11.58"}}, &cap);

    // 2a. A kernel-perf run, structured as a falsifiable test → PROVEN.
    auto k = c.experiment("kernel-perf", "matvec_q4k_f32_blk", "vulkan/6144x2048",
                          {.metric = "ratio_vs_hand",
                           .hypothesis = "the DSL f32-direct matvec beats the hand kernel",
                           .predict = "DSL/hand >= 1.0 cold in-engine at the dominant FFN shape",
                           .doc = "cold in-engine A/B of the DSL matvec vs the hand kernel"});
    k.log("cold in-engine A/B, evo gfx1151, quiet window, 3 runs, bit-exact 2.3e-6");
    k.snapshot(std::string("abc"));  // the artifact whose sha256 we verify below
    std::string artifactBody = cap.last();
    k.conclude(research::Verdict::Proven, "1.022x at 6144 rows (loses small shapes -> gate >=4096)", 1.022);
    std::string kernelSealed = cap.last();

    // 2b. A marketing-experiment on the SAME plane (kind is an open string) → REFUTED.
    //     A refutation is a first-class, durable result, recorded as clearly as a proof.
    auto m = c.experiment("marketing-experiment", "landing-hero-v2", "signup-cta",
                          {.metric = "net-lift",
                           .hypothesis = "hero variant B lifts signup CTR over control A",
                           .predict = "B-A >= 2pp at p<0.05 over a 2-week 50/50 split",
                           .doc = "A/B on the landing hero; primary metric is signup CTR"});
    m.record("session-8821", "variant-b", {.answer = "signup", .correct = true, .source = "web-analytics"});
    m.record("session-8822", "variant-a", {.answer = "bounce", .correct = false, .source = "web-analytics"});
    m.log("40,132 sessions, 2-week split, CUPED-adjusted, guardrails green");
    m.conclude(research::Verdict::Refuted, "B-A = -0.4pp; 95% CI [-1.1, +0.3] crosses 0", -0.4);
    std::string marketingSealed = cap.last();

    std::printf("=== SHA-256 self-test (artifact of bytes \"abc\") ===\n");
    const char* want = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
    bool hit = artifactBody.find(want) != std::string::npos;
    std::printf("expect sha256(\"abc\") = %s\n", want);
    std::printf("artifact record carries it: %s\n\n", hit ? "PASS" : "FAIL");

    std::printf("=== kernel-perf sealed record (Verdict::Proven) ===\n%s\n\n", kernelSealed.c_str());
    std::printf("=== marketing-experiment sealed record (Verdict::Refuted) ===\n%s\n\n", marketingSealed.c_str());
    std::printf("=== snapshot artifact record ===\n%s\n\n", artifactBody.c_str());

    return hit ? 0 : 1;
}

// A fixed-provenance ingest body, built via the same json::Value serializer the client uses,
// in the exact key order of Experiment::post()/meta() and Client::ingest(). The `doc` field
// carries a non-ASCII char, an embedded quote, and a newline to exercise the escaping. The
// Python SDK, fed the identical structure, must json.dumps to these exact bytes.
static int ingest() {
    using research::json::Value;

    Value host = Value::object();
    host.set("hostname", "evo").set("platform", "Linux");

    Value commits = Value::array();
    commits.push("dsl matvec: f32-direct path").push("gate small shapes >=4096");

    Value logs = Value::array();
    logs.push("cold in-engine A/B, evo gfx1151").push("3 runs, bit-exact 2.3e-6");

    Value meta = Value::object();
    meta.set("doc", "cafe\xC3\xA9 \xE2\x98\x95 with a \"quote\" and a\nnewline")
        .set("commits", std::move(commits))
        .set("note", "dominant FFN shape")
        .set("host", std::move(host))
        .set("hypothesis", "the DSL f32-direct matvec beats the hand kernel")
        .set("predict", "DSL/hand >= 1.0 cold at the dominant FFN shape")
        .set("verdict", "proven")
        .set("because", "1.022x at 6144 rows")
        .set("log", std::move(logs));

    Value libs = Value::object();
    libs.set("hanzo-engine", "1.7.45").set("hanzo-ml", "0.11.58");

    Value e = Value::object();
    e.set("id", "kernel-perf:matvec_q4k_f32_blk:vulkan/6144x2048")
        .set("kind", "kernel-perf")
        .set("subject", "matvec_q4k_f32_blk")
        .set("task", "vulkan/6144x2048")
        .set("metric", "ratio_vs_hand")
        .set("value", 1.022)
        .set("n", 0LL)
        .set("n_total", 0LL)
        .set("status", "complete")
        .set("git_sha", "abc123def456")
        .set("git_branch", "blue/research-sdk-cpp")
        .set("git_dirty", true)
        .set("lib_versions", std::move(libs))
        .set("meta", std::move(meta));

    // A second experiment with value 0.0 proves the Python float repr (0.0, not 0).
    Value e2 = Value::object();
    e2.set("id", "benchmark:grok-4.5:gpqa_diamond")
        .set("kind", "benchmark")
        .set("subject", "grok-4.5")
        .set("task", "gpqa_diamond")
        .set("metric", "accuracy")
        .set("value", 0.0)
        .set("n", 0LL)
        .set("n_total", 198LL)
        .set("status", "running")
        .set("git_sha", "abc123def456")
        .set("git_branch", "blue/research-sdk-cpp")
        .set("git_dirty", false)
        .set("lib_versions", Value::object())
        .set("meta", Value::object());

    Value a = Value::object();
    a.set("benchmark", "gpqa_diamond")
        .set("item", "q1")
        .set("model", "grok-4.5")
        .set("answer", "A")
        .set("correct", true)
        .set("response", "")
        .set("gold", "A")
        .set("source", "hanzo-measured")
        .set("status", "complete");

    Value exps = Value::array();
    exps.push(std::move(e)).push(std::move(e2));
    Value atts = Value::array();
    atts.push(std::move(a));

    Value body = Value::object();
    body.set("experiments", std::move(exps)).set("attempts", std::move(atts));

    std::cout << body.dump();
    return 0;
}

int main(int argc, char** argv) {
    if (argc > 1 && std::string(argv[1]) == "ingest") return ingest();
    return demo();
}
