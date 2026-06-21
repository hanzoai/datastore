# Benchmarks

SQL benchmarks for Datastore. Each subdirectory contains a self-contained benchmark with the following structure:


| File / Directory | Description                                                                                                |
| ---------------- | ---------------------------------------------------------------------------------------------------------- |
| `init.sql`       | Schema definitions (CREATE TABLE statements)                                                               |
| `settings.json`  | Datastore settings to use when running the queries (to make it SQL-standard compliant) |
| `queries/`       | The query files                                                                                  |
