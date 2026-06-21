#!/usr/bin/env bash
CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

db="rdb_$DATASTORE_DATABASE"

$DATASTORE_CLIENT --distributed_ddl_output_mode=none -nq "
    create database $db engine=Replicated('/test/$DATASTORE_DATABASE/rdb', 's1', 'r1');
    create table $db.a (x Int8) engine ReplicatedMergeTree order by x;"
uuid=`$DATASTORE_CLIENT -q "select uuid from system.tables where database = '$db' and name = 'a'"`
$DATASTORE_CLIENT --distributed_ddl_output_mode=none -nq "
    select count() from system.zookeeper where path = '/datastore/tables' and name = '$uuid';
    drop table $db.a sync;
    select count() from system.zookeeper where path = '/datastore/tables' and name = '$uuid';"
$DATASTORE_CLIENT -q "drop database $db"
