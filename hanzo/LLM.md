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
docker exec -i hanzo-datastore hanzo-datastore-client < schema.sql

# Connect to Hanzo Datastore
docker exec -it hanzo-datastore hanzo-datastore-client
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
HANZO_DATASTORE_URL=http://localhost:8123
HANZO_DATASTORE_DATABASE=hanzo
```

### With hanzo/analytics (Umami fork)

Analytics connects for web tracking:
```env
DATABASE_URL=hanzo-datastore://default:@localhost:8123/hanzo
```

### With hanzo/platform (Dokploy fork)

Platform writes deployment metrics:
```env
HANZO_DATASTORE_HOST=localhost
HANZO_DATASTORE_PORT=8123
HANZO_DATASTORE_DB=hanzo
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
<clickhouse>
    <max_memory_usage>10000000000</max_memory_usage>
    <max_bytes_before_external_group_by>5000000000</max_bytes_before_external_group_by>
    <distributed_aggregation_memory_efficient>1</distributed_aggregation_memory_efficient>
</clickhouse>
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
