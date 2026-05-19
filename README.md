<div align=center>

[![Website](https://img.shields.io/website?up_message=AVAILABLE&down_message=DOWN&url=https%3A%2F%2Fhanzo.ai&style=for-the-badge)](https://hanzo.ai)
[![Apache 2.0 License](https://img.shields.io/badge/license-Apache%202.0-blueviolet?style=for-the-badge)](https://www.apache.org/licenses/LICENSE-2.0)

# Hanzo Datastore

<h4>Hanzo Datastore is an open-source column-oriented database management system that allows generating analytical data reports in real-time.</h4>

<h4>High-performance columnar analytics engine for the Hanzo AI ecosystem.</h4>

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

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

Apache License 2.0. See [LICENSE](LICENSE) for details.

## About Hanzo AI

<<<<<<< HEAD
Hanzo AI (Techstars '17) builds AI infrastructure including:
- **Hanzo LLM Gateway** - Unified API for 100+ LLM providers
- **Hanzo MCP** - Model Context Protocol tools
- **Hanzo Datastore** - Real-time analytics database
- **Hanzo Network** - Decentralized AI compute marketplace

Learn more at [hanzo.ai](https://hanzo.ai)
=======
Upcoming meetups
* [AI Builders Night San Jose](https://luma.com/xoq2dz0l) - March 16th, 2026
* [Munich Meetup](https://www.meetup.com/clickhouse-meetup-munich/events/313487152/) - March 19th, 2026
* [NY Meetup](https://luma.com/c7tprb51) - March 19th, 2026
* [RSA Iceberg Meetup SF](https://luma.com/rsa-iceberg) - March 24th, 2026 
* [Milan Meetup](https://www.meetup.com/clickhouse-italy-user-group/events/313586581/) - March 26th, 2026
* [Seattle Observability Meetup](https://luma.com/vph3jbkm) - March 26th, 2026
* [San Francisco Observability FireSide Chat](https://luma.com/v5d8u087) - March 31st, 2026
* [AI Demo Night SF](https://luma.com/jyzlu78v) - April 9th, 2026
* [Taipei Open Source Night](https://luma.com/kt3xtz3a) - April 16th, 2026

Recent meetups
* [Apache Iceberg™ Meetup Pittsburgh](https://luma.com/mqgwk79x) - March 12th, 2026
* [SRE Days London Meetup](https://luma.com/sreday-2026-london-q1) - March 12, 2026
* [San Francisco Meetup](https://luma.com/6rnu6wzs) - March 11th, 2026
* [Sao Paulo Meetup](https://www.meetup.com/clickhouse-brasil-user-group/events/313294062) - March 10th, 2026
* [Women+ in open source](https://luma.com/qcqlia4g) - March 9th, 2026 
* [Tokyo Meetup - LibreChat Night](https://www.meetup.com/clickhouse-tokyo-user-group/events/313275265/) - March 9th, 2026
* [LA Meetup](https://luma.com/wbkqmaqk) - March 6th, 2026
* [Bangalore GDG + Deutsche Bank Meetup](https://www.meetup.com/clickhouse-bangalore-user-group/events/313325219/) - February 28th, 2026
* [Seattle Meetup](https://luma.com/jsctpwoa) - February 26th, 2026
* [Melbourne Meetup](https://www.meetup.com/clickhouse-melbourne-user-group/events/312871833/) - February 24th, 2026




## Recent Recordings

* **Recent Meetup Videos**: [Meetup Playlist](https://www.youtube.com/playlist?list=PL0Z2YDlm0b3iNDUzpY1S3L_iV4nARda_U) Whenever possible recordings of the ClickHouse Community Meetups are edited and presented as individual talks. 

## Interested in joining ClickHouse and making it your full-time job?

ClickHouse is a nice DBMS, and it's a good place to work.

Check out our **current openings** here: https://clickhouse.com/company/careers

Email: careers@clickhouse.com!
>>>>>>> v26.3.10.62-lts
