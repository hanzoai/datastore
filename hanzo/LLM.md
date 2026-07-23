# Hanzo Datastore

## Overview

**Hanzo Datastore** is a column-oriented database for real-time analytics, based on ClickHouse and optimized for the Hanzo AI platform's unified analytics needs. It provides:

- **Web Analytics** - Privacy-focused visitor tracking (from Umami)
- **AI Observability** - LLM traces, costs, latency (from LangFuse)
- **Business Metrics** - Revenue, conversions, API usage
- **Infrastructure Metrics** - Base instances, app deployments

Repository: https://github.com/hanzoai/datastore

## Quick Start

```bash
# Start Hanzo Datastore with schema
cd hanzo
docker compose up -d

# Initialize schema
docker exec -i datastore datastore-client < schema.sql

# Connect to Hanzo Datastore
docker exec -it datastore datastore-client
```

## Hanzo Schema

The unified schema lives in `hanzo/schema.sql` and includes:

### Core Tables

| Table | Purpose | Source |
|-------|---------|--------|
| `organizations` | Tenant isolation | Hanzo |
| `projects` | Project scoping | Hanzo |
| `website_events` | Page views, custom events | Umami |
| `event_properties` | Event key-value data | Umami |
| `session_properties` | Session-level data | Umami |
| `ai_traces` | Conversation threads | LangFuse |
| `ai_observations` | LLM calls, spans | LangFuse |
| `ai_scores` | Evaluations, metrics | LangFuse |
| `business_events` | Purchases, signups | Hanzo |
| `api_metrics` | API usage tracking | Hanzo |
| `base_metrics` | PocketBase instances | Hanzo |
| `app_metrics` | App deployments | Hanzo |
| `model_catalog` | LLM pricing/config | Hanzo |

### Materialized Views

Real-time aggregations for dashboards:

- `website_events_hourly_mv` - Web analytics rollups
- `ai_usage_daily_mv` - AI usage by model
- `api_metrics_hourly_mv` - API performance

## Integration Points

### With hanzo/console (LangFuse fork)

Console connects for AI observability:
```env
DATASTORE_URL=http://localhost:8123
DATASTORE_DATABASE=hanzo
```

### With hanzo/analytics (Umami fork)

Analytics connects for web tracking:
```env
DATABASE_URL=datastore://default:@localhost:8123/hanzo
```

### With hanzo/platform (Dokploy fork)

Platform writes deployment metrics:
```env
DATASTORE_HOST=localhost
DATASTORE_PORT=8123
DATASTORE_DB=hanzo
```

## Research client (C++) — `research.hpp` / `research.cpp`

The C++ port of the Hanzo Research SDK: the ONE way a native producer (a kernel, a
benchmark, the datastore/luxcpp stack) records + queries R&D evidence on the unified
`/v1/research` plane (HIP-0512). It mirrors the Python `hanzo-research` SDK verb-for-verb
and is **byte-identical on the wire** (same key order, `ensure_ascii`, float repr), so every
language emits uniform records into the one store.

```cpp
#include "research.hpp"
namespace research = hanzo::research;

research::Client c;                                   // base/key/project from the env
auto k = c.experiment("kernel-perf", "matvec_q4k_f32_blk", "vulkan/6144x2048",
                      {.metric = "ratio_vs_hand",
                       .hypothesis = "the DSL f32-direct matvec beats the hand kernel",
                       .predict    = "DSL/hand >= 1.0 cold at the dominant FFN shape"});
k.log("cold in-engine A/B, evo gfx1151, 3 runs, bit-exact 2.3e-6");
k.conclude(research::Verdict::Proven, "1.022x at 6144 rows", 1.022);  // git sha auto-stamped
```

- **Verbs**: `experiment(kind, subject, task, opts)` → `record` / `log` (chainable) /
  `snapshot` / `report` / `conclude(Verdict, because, value)` / `finish`; reads `query` /
  `totals`; low-level `ingest` / `artifact` / `grant`. `Verdict{Proven,Refuted,Inconclusive}`
  is type-safe — a refutation is a first-class result.
- **`kind` is an open string** — `benchmark`, `kernel-perf`, `training`, `ablation`,
  `policy-eval` AND `marketing-experiment`, `ad-test`, `growth-experiment`. No kind enum.
- **Zero-config provenance**: the constructor auto-captures git sha/branch/dirty, the commit
  narrative since the experiment's last recorded run, host, and caller-supplied lib versions.
- **Auth**: per-org key (`Authorization: Bearer $HANZO_API_KEY`) + `X-Project-Id`. The key is
  KMS-sourced via the env (KMSSecret → K8s Secret → env); never hardcoded, never logged. The
  client never sends `X-Org-Id` (server-injected from the validated principal).
- **Deps**: the record-serialization + provenance core is dependency-free (hand-rolled ordered
  JSON, SHA-256, base64 — standard library only). HTTP is the one swappable `Transport` seam;
  the production transport is **libcurl** (TLS to api.hanzo.ai), gated by `-DHANZO_RESEARCH_CURL`
  and vendored at `contrib/curl`. A test/sidecar injects its own transport.

```bash
# Zero-dep core (any producer can vendor the two files):
g++ -std=c++17 -O2 research.cpp research_example.cpp -o research_example && ./research_example
# Production build (links libcurl):
cmake -S hanzo -B build && cmake --build build && ctest --test-dir build
```

## Syncing with Upstream ClickHouse

```bash
# Fetch upstream changes
git fetch upstream

# Merge upstream master
git merge upstream/master

# Resolve conflicts (keep hanzo/ directory)
git checkout --ours hanzo/

# Push to origin
git push origin master
```

## Performance Tuning

### Recommended Settings

```xml
<!-- config.d/hanzo.xml -->
<datastore>
    <max_memory_usage>10000000000</max_memory_usage>
    <max_bytes_before_external_group_by>5000000000</max_bytes_before_external_group_by>
    <distributed_aggregation_memory_efficient>1</distributed_aggregation_memory_efficient>
</datastore>
```

### Partitioning Strategy

All time-series tables use monthly partitioning:
- `PARTITION BY toYYYYMM(timestamp)`
- TTL for metrics tables: 90 days
- No TTL for analytics (permanent storage)

### Compression

Large text fields use ZSTD(3):
- `input` / `output` in AI tables
- Reduces storage by ~70% for JSON payloads

## Docker Compose

See `hanzo/compose.yml` for local development setup with:
- Hanzo Datastore server
- Hanzo Datastore Keeper (for replication)
- Grafana for visualization

## Related Repositories

- **hanzo/console** - AI observability platform (LangFuse fork)
- **hanzo/analytics** - Web analytics (Umami fork)
- **hanzo/platform** - PaaS deployment (Dokploy fork)
- **hanzo/relational** - PostgreSQL fork (OLTP)
- **hanzo/memory** - Redis fork (caching)
