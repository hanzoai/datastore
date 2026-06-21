-- Tags: no-fasttest

DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier};
CREATE DATABASE {DATASTORE_DATABASE_1:Identifier} ENGINE = MySQL('127.0.0.1:3456', conv_main, 'metrika', 'password'); -- { serverError CANNOT_CREATE_DATABASE }
