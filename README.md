<div align=center>

[![Website](https://img.shields.io/website?up_message=AVAILABLE&down_message=DOWN&url=https%3A%2F%2Fhanzo.ai&style=for-the-badge)](https://hanzo.ai)
[![Apache 2.0 License](https://img.shields.io/badge/license-Apache%202.0-blueviolet?style=for-the-badge)](https://www.apache.org/licenses/LICENSE-2.0)

# Hanzo Datastore

<h4>Hanzo Datastore is an open-source column-oriented database management system that allows generating analytical data reports in real-time.</h4>

<h5>Based on ClickHouse - optimized for AI analytics and Hanzo ecosystem integration.</h5>

</div>

## How To Install (Linux, macOS, FreeBSD)

```bash
curl https://hanzo.ai/datastore/install | sh
```

Or using Docker:

```bash
docker pull hanzoai/datastore:latest
docker run -d -p 8123:8123 -p 9000:9000 hanzoai/datastore:latest
```

## Quick Start with Docker Compose

```bash
cd hanzo
docker compose up -d
```

This starts:
- **Hanzo Datastore** on ports 8123 (HTTP) and 9000 (Native)
- **Keeper** (distributed coordination) on port 9181
- **Grafana** on port 3030 for visualization

## Features

- **Real-time Analytics**: Sub-second queries on billions of rows
- **Column-oriented Storage**: Optimized for analytical workloads
- **SQL Compatible**: Standard SQL with extensions for analytics
- **Scalable**: From single node to distributed clusters
- **Hanzo Integration**: Built-in support for Hanzo unified analytics schema

## Documentation

* [Official Documentation](https://hanzo.ai/docs/datastore)
* [API Reference](https://hanzo.ai/docs/datastore/api)
* [Hanzo Ecosystem](https://hanzo.ai)

## Useful Links

* [Hanzo AI](https://hanzo.ai) - AI infrastructure platform
* [GitHub Repository](https://github.com/hanzoai/datastore)
* [Issue Tracker](https://github.com/hanzoai/datastore/issues)

## Based on ClickHouse

Hanzo Datastore is a fork of [ClickHouse](https://clickhouse.com), the world's fastest open-source OLAP database. We maintain compatibility with upstream ClickHouse while adding Hanzo-specific integrations and optimizations.

### Upstream Resources

* [ClickHouse Documentation](https://clickhouse.com/docs)
* [ClickHouse GitHub](https://github.com/ClickHouse/ClickHouse)

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

Apache License 2.0. See [LICENSE](LICENSE) for details.

## About Hanzo AI

Hanzo AI (Techstars '17) builds AI infrastructure including:
- **Hanzo LLM Gateway** - Unified API for 100+ LLM providers
- **Hanzo MCP** - Model Context Protocol tools
- **Hanzo Datastore** - Real-time analytics database
- **Hanzo Network** - Decentralized AI compute marketplace

Learn more at [hanzo.ai](https://hanzo.ai)
