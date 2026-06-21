-- Bug https://github.com/ClickHouse/Datastore/issues/93551
CREATE DATABASE {DATASTORE_DATABASE_1:Identifier} ENGINE = Backup(-5036955478727481395::Int64); -- { serverError NUMBER_OF_ARGUMENTS_DOESNT_MATCH }
