-- https://github.com/ClickHouse/Datastore/issues/78392
SET output_format_parquet_batch_size = 0; -- { serverError BAD_ARGUMENTS }