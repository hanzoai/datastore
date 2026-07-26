<div align=center>

[![Website](https://img.shields.io/website?up_message=AVAILABLE&down_message=DOWN&url=https%3A%2F%2Fhanzo.ai&style=for-the-badge)](https://hanzo.ai)
[![Apache 2.0 License](https://img.shields.io/badge/license-Apache%202.0-blueviolet?style=for-the-badge)](https://www.apache.org/licenses/LICENSE-2.0)

<picture align=center>
    <source media="(prefers-color-scheme: dark)" srcset="docs/logo/dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="docs/logo/light.svg">
    <img alt="Hanzo Datastore" src="docs/logo/light.svg">
</picture>

<h4>Hanzo Datastore is a column-oriented database for real-time analytical queries.</h4>

</div>

## What it is

Datastore is the OLAP half of Hanzo's data platform. It is a fork of
[ClickHouse](https://github.com/ClickHouse/ClickHouse), narrowed to one job and
rebuilt around separated storage and compute.

`MergeTree` parts are stored as objects on [Hanzo S3](https://github.com/hanzoai/s3),
so stateless compute replicas share a single zero-copy copy of the data instead of
each carrying its own. Scaling out adds query capacity without adding storage.

## Run

The published image is `ghcr.io/hanzoai/datastore`, built multi-arch by CI from
`docker/server/Dockerfile.ubuntu`.

```bash
cd hanzo && docker compose up
```

Debian and RPM packages are built from `packages/` — `datastore-server`,
`datastore-client` and `datastore-common-static`.

## Connect

| Port | Protocol | Purpose |
|------|----------|---------|
| 9000 | TCP | native binary protocol — the live query path |
| 8123 | HTTP | HTTP interface |
| 9009 | TCP | interserver replication |
| 9181 | TCP | embedded coordination client port |

HTTP requests authenticate with `X-Datastore-User` and `X-Datastore-Key`, or with
HTTP Basic, or with `?user=` and `?password=` query parameters. The server also
returns `X-Datastore-Query-Id`, `X-Datastore-Format`, `X-Datastore-Summary` and
`X-Datastore-Exception-Code`.

```bash
curl -H 'X-Datastore-User: default' -H 'X-Datastore-Key: ' \
     --data 'SELECT version()' http://localhost:8123/
```

## How it differs from upstream

**One binary.** `datastore` is the only server binary. Coordination runs in-process
whenever `<keeper_server>` is present in the config — there is no separate keeper
process to deploy.

**OLAP only.** External stream brokers and foreign-database read/CDC engines are
disabled at build time: Kafka, RabbitMQ, MySQL, PostgreSQL, MongoDB, HDFS, Hive,
Cassandra, YTsaurus. Their source trees remain behind `USE_*` macros so upstream
merges stay clean. `MergeTree` and its replicated and distributed variants, `S3`,
`ObjectStorage`, `File`, `URL`, `Memory`, `Log`, views, `RocksDB` and dictionaries
are kept.

**No gRPC, no Arrow Flight.** Both RPC surfaces are removed. The replacement
transport is ZAP, a Cap'n-Proto-derived RPC; its server stub has landed but is not
yet the query path.

**Coordination is moving off Raft.** The ZooKeeper API stays — it is the contract
that replicated tables speak — while the engine underneath is being replaced with
[Quasar](https://github.com/luxfi/consensus), which is post-quantum and leaderless.
The engine is proven single-node and tested; the multi-node cutover is in progress.

## Performance

ClickBench, 43 queries against the 100M-row `hits` dataset, aarch64, 4 runs per
query, warm cache. Compared against the official ClickHouse binary:

| Metric | ClickHouse | Datastore | Delta |
|--------|-----------|-----------|-------|
| Peak RSS under load | 14.52 GB | 13.96 GB | −3.8% |
| Total query time | 16.83 s | 16.82 s | tied |
| Per-query | — | faster on 8 of 43 | ~neutral |

Read that honestly: at production scale the build buys about 4% less peak memory
and is statistically tied on speed. An earlier "half the memory, much faster"
figure was real but measured at **10M rows**, where a leaner binary is a large
share of a small working set; at 100M rows the data dominates and the same fixed
saving shrinks. Never quote the 10M number without its scale. The 100M run is one
workload on one machine with per-query noise around ±25%, so "tied" is within
noise. The fork's value is architectural, not raw speed over stock.

## Upstream

Upstream is [ClickHouse/ClickHouse](https://github.com/ClickHouse/ClickHouse). A
scheduled workflow merges `upstream/master` into a dated branch weekly and opens a
draft pull request; it never auto-merges, and a conflicted merge is pushed with
markers intact and labelled. Net-new Hanzo files live under `hanzo/`, disjoint from
upstream, so most syncs land clean.

## Links

* [hanzo.ai](https://hanzo.ai) — Hanzo AI
* [docs.hanzo.ai](https://docs.hanzo.ai) — documentation
* [hanzo.ai/blog](https://hanzo.ai/blog) — announcements

## License

Apache-2.0. Forked from ClickHouse at v26.6.1.1, Copyright 2016-2026 ClickHouse,
Inc. See [NOTICE](NOTICE) for attribution and the full list of deviations from
upstream.
