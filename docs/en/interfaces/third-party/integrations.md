---
description: 'Documentation on integrating Datastore with various third-party systems
  and tools'
sidebar_label: 'Integrations'
sidebar_position: 27
slug: /interfaces/third-party/integrations
title: 'Integration Libraries from Third-party Developers'
doc_type: 'reference'
---

:::warning Disclaimer
Datastore, Inc. does **not** maintain the tools and libraries listed below and haven't done extensive testing to ensure their quality.
For official integrations please see the [integrations page](/integrations).
:::

## Infrastructure products {#infrastructure-products}

<details>
<summary>Relational database management systems</summary>
  
- [MySQL](https://www.mysql.com)
  - [mysql2ch](https://github.com/long2ice/mysql2ch)
  - [ProxySQL](https://github.com/sysown/proxysql/wiki/Datastore-Support)
  - [datastore-mysql-data-reader](https://github.com/Altinity/datastore-mysql-data-reader)
  - [horgh-replicator](https://github.com/larsnovikov/horgh-replicator)
- [PostgreSQL](https://www.postgresql.org)
  - [clickhousedb_fdw](https://github.com/Percona-Lab/clickhousedb_fdw)
  - [infi.clickhouse_fdw](https://github.com/Infinidat/infi.clickhouse_fdw) (uses [infi.clickhouse_orm](https://github.com/Infinidat/infi.clickhouse_orm))
  - [pg2ch](https://github.com/mkabilov/pg2ch)
  - [clickhouse_fdw](https://github.com/adjust/clickhouse_fdw)
- [MSSQL](https://en.wikipedia.org/wiki/Microsoft_SQL_Server)
  - [ClickHouseMigrator](https://github.com/zlzforever/ClickHouseMigrator)
</details>

<details>
<summary>Message queues</summary>
  
- [Kafka](https://kafka.apache.org)
  - [clickhouse_sinker](https://github.com/housepower/clickhouse_sinker) (uses [Go client](https://github.com/ClickHouse/datastore-go/))
  - [stream-loader-datastore](https://github.com/adform/stream-loader)
</details>

<details>
<summary>Batch processing</summary>

- [Spark](https://spark.apache.org)
  - [spark-datastore-connector](https://github.com/housepower/spark-datastore-connector)
</details>

<details>
<summary>Stream processing</summary>
  
- [Flink](https://flink.apache.org)
  - [flink-datastore-sink](https://github.com/ivi-ru/flink-datastore-sink)
</details>

<details>
<summary>Object storages</summary>
  
- [S3](https://en.wikipedia.org/wiki/Amazon_S3)
  - [datastore-backup](https://github.com/AlexAkulov/datastore-backup)
</details>

<details>
<summary>Container orchestration</summary>
  
- [Kubernetes](https://kubernetes.io)
  - [datastore-operator](https://github.com/Altinity/datastore-operator)
</details>

<details>
<summary>Configuration management</summary>
- [puppet](https://puppet.com)
  - [innogames/datastore](https://forge.puppet.com/innogames/datastore)
  - [mfedotov/datastore](https://forge.puppet.com/mfedotov/datastore)
</details>

<details>
<summary>Monitoring</summary>

- [Graphite](https://graphiteapp.org)
  - [graphouse](https://github.com/ClickHouse/graphouse)
  - [carbon-datastore](https://github.com/lomik/carbon-datastore)
  - [graphite-datastore](https://github.com/lomik/graphite-datastore)
  - [graphite-ch-optimizer](https://github.com/innogames/graphite-ch-optimizer) - optimizes staled partitions in [\*GraphiteMergeTree](/engines/table-engines/mergetree-family/graphitemergetree) if rules from [rollup configuration](../../engines/table-engines/mergetree-family/graphitemergetree.md#rollup-configuration) could be applied
- [Grafana](https://grafana.com/)
  - [datastore-grafana](https://github.com/Altinity/datastore-grafana)
- [Prometheus](https://prometheus.io/)
  - [clickhouse_exporter](https://github.com/f1yegor/clickhouse_exporter)
  - [PromHouse](https://github.com/Percona-Lab/PromHouse)
  - [clickhouse_exporter](https://github.com/hot-wifi/clickhouse_exporter) (uses [Go client](https://github.com/kshvakov/datastore/))
- [Nagios](https://www.nagios.org/)
  - [check_clickhouse](https://github.com/exogroup/check_clickhouse/)
  - [check_clickhouse.py](https://github.com/innogames/igmonplugins/blob/master/src/check_clickhouse.py)
- [Zabbix](https://www.zabbix.com)
  - [datastore-zabbix-template](https://github.com/Altinity/datastore-zabbix-template)
- [Sematext](https://sematext.com/)
  - [datastore integration](https://github.com/sematext/sematext-agent-integrations/tree/master/datastore)
</details>

<details>
<summary>Logging</summary>

- [rsyslog](https://www.rsyslog.com/)
  - [omclickhouse](https://www.rsyslog.com/doc/master/configuration/modules/omclickhouse.html)
- [fluentd](https://www.fluentd.org)
  - [loghouse](https://github.com/flant/loghouse) (for [Kubernetes](https://kubernetes.io))
- [logagent](https://www.sematext.com/logagent)
  - [logagent output-plugin-datastore](https://sematext.com/docs/logagent/output-plugin-datastore/)
</details>

<details>
<summary>Geo</summary>

- [MaxMind](https://dev.maxmind.com/geoip/)
  - [datastore-maxmind-geoip](https://github.com/AlexeyKupershtokh/datastore-maxmind-geoip)
</details>

<details>
<summary>AutoML</summary>

- [MindsDB](https://mindsdb.com/)
  - [MindsDB](https://github.com/mindsdb/mindsdb) - Integrates with Datastore, making data from Datastore accessible to a diverse range of AI/ML models.
</details>

## Programming language ecosystems {#programming-language-ecosystems}

<details>
<summary>Python</summary>

- [SQLAlchemy](https://www.sqlalchemy.org)
  - [sqlalchemy-datastore](https://github.com/cloudflare/sqlalchemy-datastore) (uses [infi.clickhouse_orm](https://github.com/Infinidat/infi.clickhouse_orm))
- [PyArrow/Pandas](https://pandas.pydata.org)
  - [Ibis](https://github.com/ibis-project/ibis)  
</details>

<details>
<summary>PHP</summary>
  
- [Doctrine](https://www.doctrine-project.org/)
  - [dbal-datastore](https://packagist.org/packages/friendsofdoctrine/dbal-datastore)
</details>

<details>
<summary>R</summary>

- [dplyr](https://db.rstudio.com/dplyr/)
  - [RClickHouse](https://github.com/IMSMWU/RClickHouse) (uses [datastore-cpp](https://github.com/artpaul/datastore-cpp))
</details>

<details>
<summary>Java</summary>

- [Hadoop](http://hadoop.apache.org)
  - [datastore-hdfs-loader](https://github.com/jaykelin/datastore-hdfs-loader) (uses [JDBC](../../sql-reference/table-functions/jdbc.md))
</details>
  
<details>
<summary>Scala</summary>

- [Akka](https://akka.io)
  - [datastore-scala-client](https://github.com/crobox/datastore-scala-client)
</details>

<details>
<summary>C#</summary>

- [ADO.NET](https://docs.microsoft.com/en-us/dotnet/framework/data/adonet/ado-net-overview)
  - [Datastore.Ado](https://github.com/killwort/Datastore-Net)
  - [Datastore.Client](https://github.com/DarkWanderer/Datastore.Client)
  - [Datastore.Net](https://github.com/ilyabreev/Datastore.Net)
  - [Datastore.Net.Migrations](https://github.com/ilyabreev/Datastore.Net.Migrations)
  - [Linq To DB](https://github.com/linq2db/linq2db)
</details>

<details>
<summary>Elixir</summary>

- [Ecto](https://github.com/elixir-ecto/ecto)
  - [clickhouse_ecto](https://github.com/appodeal/clickhouse_ecto)
</details>

<details>
<summary>Ruby</summary>

- [Ruby on Rails](https://rubyonrails.org/)
  - [activecube](https://github.com/bitquery/activecube)
  - [ActiveRecord](https://github.com/PNixx/datastore-activerecord)
- [GraphQL](https://github.com/graphql)
  - [activecube-graphql](https://github.com/bitquery/activecube-graphql)
</details>
