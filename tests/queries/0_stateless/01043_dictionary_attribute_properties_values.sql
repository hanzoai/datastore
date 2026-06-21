
CREATE TABLE {DATASTORE_DATABASE:Identifier}.dicttbl(key Int64, value_default String, value_expression String) ENGINE = MergeTree ORDER BY tuple();
INSERT INTO {DATASTORE_DATABASE:Identifier}.dicttbl VALUES (12, 'hello', '55:66:77');


CREATE DICTIONARY {DATASTORE_DATABASE:Identifier}.dict
(
  key Int64 DEFAULT -1,
  value_default String DEFAULT 'world',
  value_expression String DEFAULT 'xxx' EXPRESSION 'toString(127 * 172)'

)
PRIMARY KEY key
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'dicttbl' DB currentDatabase()))
LAYOUT(FLAT())
LIFETIME(1);


SELECT dictGetString({DATASTORE_DATABASE:String} || '.dict', 'value_default', toUInt64(12));
SELECT dictGetString({DATASTORE_DATABASE:String} || '.dict', 'value_default', toUInt64(14));

SELECT dictGetString({DATASTORE_DATABASE:String} || '.dict', 'value_expression', toUInt64(12));
SELECT dictGetString({DATASTORE_DATABASE:String} || '.dict', 'value_expression', toUInt64(14));
