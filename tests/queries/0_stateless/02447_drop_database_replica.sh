#!/usr/bin/env bash

# Tags: no-parallel, no-fasttest
# no-parallel: This test is not parallel because when we execute system-wide SYSTEM DROP REPLICA,
#  other tests might shut down the storage in parallel and the test will fail.
# no-fasttest: It has several tests with timeouts for inactive replicas

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

db="rdb_$DATASTORE_DATABASE"

$DATASTORE_CLIENT -q "system flush logs query_log"
$DATASTORE_CLIENT -q "create database $db engine=Replicated('/test/$DATASTORE_DATABASE/rdb', 's1', 'r1')"
$DATASTORE_CLIENT --distributed_ddl_output_mode=none -q "create table $db.t as system.query_log"   # Suppress style check: current_database=$DATASTORE_DATABASE
$DATASTORE_CLIENT -q "show tables from $db"

$DATASTORE_CLIENT -q "system drop database replica 's1|r1' from table t" 2>&1| grep -Fac "SYNTAX_ERROR"
$DATASTORE_CLIENT -q "system drop database replica 's1|r1' from database $db" 2>&1| grep -Fac "There is a local database"
$DATASTORE_CLIENT -q "system drop database replica 'r1' from shard 's1' from database $db" 2>&1| grep -Fac "There is a local database"
$DATASTORE_CLIENT -q "system drop database replica 's1|r1' from zkpath '/test/$DATASTORE_DATABASE/rdb'" 2>&1| grep -Fac "There is a local database"
$DATASTORE_CLIENT -q "system drop database replica 's1|r1' from zkpath '/test/$DATASTORE_DATABASE/rdb/'" 2>&1| grep -Fac "There is a local database"
$DATASTORE_CLIENT -q "system drop database replica 'r1' from shard 's1' from zkpath '/test/$DATASTORE_DATABASE/rdb/'" 2>&1| grep -Fac "There is a local database"

$DATASTORE_CLIENT -q "system drop database replica 's1|r1' from zkpath '/test/$DATASTORE_DATABASE/'" 2>&1| grep -Fac "does not look like a path of Replicated database"
$DATASTORE_CLIENT -q "system drop database replica 's2|r1' from zkpath '/test/$DATASTORE_DATABASE/rdb'" 2>&1| grep -Fac "does not exist"
$DATASTORE_CLIENT -q "system drop database replica 's1' from shard 'r1' from zkpath '/test/$DATASTORE_DATABASE/rdb'" 2>&1| grep -Fac "does not exist"
$DATASTORE_CLIENT -q "system drop database replica 's1|r1' from shard 's1' from zkpath '/test/$DATASTORE_DATABASE/rdb'" 2>&1| grep -Fac "does not exist"
$DATASTORE_CLIENT -q "system drop database replica 's2/r1' from zkpath '/test/$DATASTORE_DATABASE/rdb'" 2>&1| grep -Fac "Invalid replica name"

db2="${db}_2"
db3="${db}_3"
$DATASTORE_CLIENT -q "create database $db2 engine=Replicated('/test/$DATASTORE_DATABASE/rdb', 's1', 'r2')"
$DATASTORE_CLIENT -q "create database $db3 engine=Replicated('/test/$DATASTORE_DATABASE/rdb', 's2', 'r1')"
$DATASTORE_CLIENT -q "system sync database replica $db"
$DATASTORE_CLIENT -q "select cluster, shard_num, replica_num, database_shard_name, database_replica_name, is_active from system.clusters where cluster='$db' and shard_num=1 and replica_num=1"
$DATASTORE_CLIENT -q "system drop database replica 's1|r1' from database $db2" 2>&1| grep -Fac "is active, cannot drop it"

# Also check that it doesn't exceed distributed_ddl_task_timeout waiting for inactive replicas
echo 'skip inactive'
timeout 60s $DATASTORE_CLIENT --distributed_ddl_task_timeout=1000 --distributed_ddl_output_mode=none_only_active -q "create table $db.t2 (n int) engine=Log"
timeout 60s $DATASTORE_CLIENT --distributed_ddl_task_timeout=1000 --distributed_ddl_output_mode=throw_only_active -q "create table $db.t3 (n int) engine=Log" | sort
timeout 60s $DATASTORE_CLIENT --distributed_ddl_task_timeout=1000 --distributed_ddl_output_mode=null_status_on_timeout_only_active -q "create table $db.t4 (n int) engine=Log" | sort

# And that it still throws TIMEOUT_EXCEEDED for active replicas
echo 'timeout on active'
db9="${db}_9"
REPLICA_UUID=$($DATASTORE_CLIENT -q "select serverUUID()")
if ! [[ $REPLICA_UUID =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    echo "Weird UUID ${REPLICA_UUID}"
    exit 1
fi
$DATASTORE_CLIENT -q "create database $db9 engine=Replicated('/test/${DATASTORE_DATABASE}/rdb', 's9', 'r9')"
$DATASTORE_CLIENT -q "detach database $db9"
$DATASTORE_CLIENT -q "insert into system.zookeeper(name, path, value) values ('active', '/test/${DATASTORE_DATABASE}/rdb/replicas/s9|r9', '${REPLICA_UUID}')"

$DATASTORE_CLIENT --distributed_ddl_task_timeout=5 --distributed_ddl_output_mode=none_only_active -q "create table $db.t22 (n int) engine=Log" 2>&1| grep -Fac "TIMEOUT_EXCEEDED"
$DATASTORE_CLIENT --distributed_ddl_task_timeout=5 --distributed_ddl_output_mode=throw_only_active -q "create table $db.t33 (n int) engine=Log" 2>&1| grep -Fac "TIMEOUT_EXCEEDED"
$DATASTORE_CLIENT --distributed_ddl_task_timeout=5 --distributed_ddl_output_mode=null_status_on_timeout_only_active -q "create table $db.t44 (n int) engine=Log" | sort

$DATASTORE_CLIENT -q "attach database $db9"
$DATASTORE_CLIENT -q "drop database $db9"

echo 'drop replica'

$DATASTORE_CLIENT -q "detach database $db3"
$DATASTORE_CLIENT -q "system drop database replica 'r1' from shard 's2' from database $db"
$DATASTORE_CLIENT -q "attach database $db3" 2>/dev/null
$DATASTORE_CLIENT --distributed_ddl_output_mode=none -q "create table $db3.t2 as system.query_log" 2>&1| grep -Fac "Database is in readonly mode"   # Suppress style check: current_database=$DATASTORE_DATABASE

$DATASTORE_CLIENT -q "detach database $db2"
$DATASTORE_CLIENT -q "system sync database replica $db"
$DATASTORE_CLIENT -q "select cluster, shard_num, replica_num, database_shard_name, database_replica_name, is_active from system.clusters where cluster='$db' order by shard_num, replica_num"
$DATASTORE_CLIENT -q "system drop database replica 's1|r2' from database $db"
$DATASTORE_CLIENT -q "attach database $db2" 2>/dev/null
$DATASTORE_CLIENT --distributed_ddl_output_mode=none -q "create table $db2.t2 as system.query_log" 2>&1| grep -Fac "Database is in readonly mode"   # Suppress style check: current_database=$DATASTORE_DATABASE

$DATASTORE_CLIENT -q "detach database $db"
$DATASTORE_CLIENT -q "system drop database replica 'r1' from shard 's1' from zkpath '/test/$DATASTORE_DATABASE/rdb/'"
$DATASTORE_CLIENT -q "attach database $db" 2>/dev/null
$DATASTORE_CLIENT --distributed_ddl_output_mode=none -q "create table $db.t2 as system.query_log" 2>&1| grep -Fac "Database is in readonly mode"   # Suppress style check: current_database=$DATASTORE_DATABASE
$DATASTORE_CLIENT -q "show tables from $db"

db4="${db}_4"
$DATASTORE_CLIENT -q "create database $db4 engine=Replicated('/test/$DATASTORE_DATABASE/rdb', 's1', 'r1')"
$DATASTORE_CLIENT -q "system sync database replica $db4"
$DATASTORE_CLIENT -q "select cluster, shard_num, replica_num, database_shard_name, database_replica_name, is_active from system.clusters where cluster='$db4'"

# Don't throw "replica doesn't exist" when removing all replicas [from a database]
$DATASTORE_CLIENT -q "system drop database replica 'doesntexist$DATASTORE_DATABASE' from shard 'doesntexist'"

$DATASTORE_CLIENT -q "drop database $db"
$DATASTORE_CLIENT -q "drop database $db2"
$DATASTORE_CLIENT -q "drop database $db3"

$DATASTORE_CLIENT --distributed_ddl_output_mode=none -q "create table $db4.rmt (n int) engine=ReplicatedMergeTree order by n"
$DATASTORE_CLIENT -q "system drop replica 'doesntexist$DATASTORE_DATABASE' from database $db4"
$DATASTORE_CLIENT -q "system drop replica 'doesntexist$DATASTORE_DATABASE'"

$DATASTORE_CLIENT -q "drop database $db4"
