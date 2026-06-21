
CREATE TABLE {DATASTORE_DATABASE:Identifier}.table_for_dict
(
  key_column UInt64,
  value Float64
)
ENGINE = MergeTree()
ORDER BY key_column;

INSERT INTO {DATASTORE_DATABASE:Identifier}.table_for_dict VALUES (1, 1.1);

CREATE DICTIONARY IF NOT EXISTS {DATASTORE_DATABASE:Identifier}.dict_exists
(
  key_column UInt64,
  value Float64 DEFAULT 77.77
)
PRIMARY KEY key_column
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'table_for_dict' DB currentDatabase()))
LIFETIME(1)
LAYOUT(FLAT());

SELECT dictGetFloat64({DATASTORE_DATABASE:String} || '.dict_exists', 'value', toUInt64(1));


CREATE DICTIONARY IF NOT EXISTS {DATASTORE_DATABASE:Identifier}.dict_exists
(
  key_column UInt64,
  value Float64 DEFAULT 77.77
)
PRIMARY KEY key_column
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'table_for_dict' DB currentDatabase()))
LIFETIME(1)
LAYOUT(FLAT());

SELECT dictGetFloat64({DATASTORE_DATABASE:String} || '.dict_exists', 'value', toUInt64(1));

DROP DICTIONARY {DATASTORE_DATABASE:Identifier}.dict_exists;
DROP TABLE {DATASTORE_DATABASE:Identifier}.table_for_dict;
