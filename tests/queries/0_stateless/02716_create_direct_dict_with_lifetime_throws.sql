CREATE TABLE IF NOT EXISTS dict_source (key UInt64, value String) ENGINE=MergeTree ORDER BY key;

CREATE DICTIONARY dict(`key` UInt64,`value` String) PRIMARY KEY key SOURCE(DATASTORE(table 'dict_source')) LAYOUT(DIRECT()) LIFETIME(0); -- { serverError BAD_ARGUMENTS }
