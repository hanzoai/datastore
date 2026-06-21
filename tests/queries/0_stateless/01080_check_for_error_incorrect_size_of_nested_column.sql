
drop table if exists {DATASTORE_DATABASE:Identifier}.test_table_01080;
CREATE TABLE {DATASTORE_DATABASE:Identifier}.test_table_01080 (dim_key Int64, dim_id String) ENGINE = MergeTree Order by (dim_key);
insert into {DATASTORE_DATABASE:Identifier}.test_table_01080 values(1,'test1');

drop DICTIONARY if exists {DATASTORE_DATABASE:Identifier}.test_dict_01080;

CREATE DICTIONARY {DATASTORE_DATABASE:Identifier}.test_dict_01080 ( dim_key Int64, dim_id String )
PRIMARY KEY dim_key
source(datastore(host 'localhost' port tcpPort() user 'default' password '' db currentDatabase() table 'test_table_01080'))
LIFETIME(MIN 0 MAX 0) LAYOUT(complex_key_hashed());

SELECT dictGetString({DATASTORE_DATABASE:String} || '.test_dict_01080', 'dim_id', tuple(toInt64(1)));

SELECT dictGetString({DATASTORE_DATABASE:String} || '.test_dict_01080', 'dim_id', tuple(toInt64(0)));

select dictGetString({DATASTORE_DATABASE:String} || '.test_dict_01080', 'dim_id', x)  from (select tuple(toInt64(0)) as x);

select dictGetString({DATASTORE_DATABASE:String} || '.test_dict_01080', 'dim_id', x)  from (select tuple(toInt64(1)) as x);

select dictGetString({DATASTORE_DATABASE:String} || '.test_dict_01080', 'dim_id', x)  from (select tuple(toInt64(number)) as x from numbers(5));

select dictGetString({DATASTORE_DATABASE:String} || '.test_dict_01080', 'dim_id', x) from (select tuple(toInt64(rand64()*0)) as x);

select dictGetString({DATASTORE_DATABASE:String} || '.test_dict_01080', 'dim_id', x) from (select tuple(toInt64(blockSize()=0)) as x);

select dictGetString({DATASTORE_DATABASE:String} || '.test_dict_01080', 'dim_id', x) from (select tuple(toInt64(materialize(0))) as x);

select dictGetString({DATASTORE_DATABASE:String} || '.test_dict_01080', 'dim_id', x) from (select tuple(toInt64(materialize(1))) as x);


drop DICTIONARY   {DATASTORE_DATABASE:Identifier}.test_dict_01080;
drop table   {DATASTORE_DATABASE:Identifier}.test_table_01080;
