-- Tags: no-parallel

create database {DATASTORE_DATABASE_1:Identifier} engine=Replicated; -- { serverError BAD_ARGUMENTS }
