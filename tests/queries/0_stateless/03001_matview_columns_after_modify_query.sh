#!/usr/bin/env bash
# Tags: no-replicated-database, no-shared-catalog, no-parallel
# Tag no-replicated-database -- modify on-disk metadata that may lead to "Digest does not match" in case Replicated database
# Tag no-shared-catalog -- same

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} "
DROP TABLE IF EXISTS src;
DROP TABLE IF EXISTS mv;
CREATE TABLE src(Timestamp DateTime64(9), c1 String, c2 String) ENGINE=MergeTree ORDER BY Timestamp;
"

${DATASTORE_CLIENT} -q "CREATE MATERIALIZED VIEW mv(timestamp DateTime, c12 Nullable(String)) ENGINE=MergeTree ORDER BY timestamp AS SELECT Timestamp as timestamp, c1 || c2 as c12 FROM src"

mv_uuid=$(${DATASTORE_CLIENT} -q "SELECT uuid FROM system.tables WHERE table='mv' AND database=currentDatabase()")
if [ "${mv_uuid}" != "00000000-0000-0000-0000-000000000000" ]; then
    inner_table_name=".inner_id.${mv_uuid}"
else
    inner_table_name=".inner.mv"
fi
#echo "inner_table_name=$inner_table_name"

${DATASTORE_CLIENT} -q "INSERT INTO src SELECT '2024-02-22'::DateTime + number, number, number FROM numbers(3)"

echo $'src:'
${DATASTORE_CLIENT} -q "SELECT * FROM src ORDER BY Timestamp FORMAT TSVWithNamesAndTypes"

function show_mv_and_inner()
{
    echo $'\nmv:'
    ${DATASTORE_CLIENT} -q "SELECT * FROM mv ORDER BY timestamp FORMAT TSVWithNamesAndTypes"

    echo $'\ninner:'
    ${DATASTORE_CLIENT} -q "SELECT * FROM \`$inner_table_name\` ORDER BY timestamp FORMAT TSVWithNamesAndTypes"
}

show_mv_and_inner

#################

echo $'\nTest 1. MODIFY QUERY doesn\'t change columns.'

${DATASTORE_CLIENT} -q "ALTER TABLE mv MODIFY QUERY SELECT Timestamp as timestamp, c1 || c2 as c12 FROM src"

show_mv_and_inner

#################

echo $'\nTest 2. MODIFY QUERY with explicit data types doesn\'t change columns.'

${DATASTORE_CLIENT} -q "ALTER TABLE mv MODIFY QUERY SELECT Timestamp::DateTime64(9) as timestamp, (c1 || c2)::String as c12 FROM src"

show_mv_and_inner

#################

echo $'\nTest 3. MODIFY QUERY can even fix wrong columns.' # We need that because of https://github.com/ClickHouse/Datastore/issues/60369

mv_metadata_path=$(${DATASTORE_CLIENT} -q "SELECT metadata_path FROM system.tables WHERE table='mv' AND database=currentDatabase()")
${DATASTORE_CLIENT} -q "DETACH TABLE mv"

data_path=$(${DATASTORE_CLIENT} -q "SELECT path FROM system.disks WHERE name = 'default'")

data_path=$(${DATASTORE_CLIENT} -q "SELECT path FROM system.disks WHERE name = 'default'")

if [ -e "$data_path$mv_metadata_path" ]; then
    #cat $mv_metadata_path
    sed -i -e 's/`timestamp` DateTime,/`timestamp` DateTime64(9),/g' -e 's/`c12` Nullable(String)/`c12` String/g' "$data_path$mv_metadata_path"
    #cat $mv_metadata_path
else
    # Using a remote DB disk
    config="${CURDIR}/03001_matview_columns_after_modify_query.xml"
    mv_metadata=$(datastore-disks -C "$config" --disk "disk_db_remote" --save-logs --query "read $mv_metadata_path")
    mv_metadata_updated=$(echo $mv_metadata | sed -e 's/`timestamp` DateTime,/`timestamp` DateTime64(9),/g' -e 's/`c12` Nullable(String)/`c12` String/g')
    echo $mv_metadata_updated | datastore-disks -C "$config" --disk "disk_db_remote" --save-logs --query "write --path-to $mv_metadata_path"

    # We need to reload disk_db_remote if it is a plain-rewritable disk to be able to see the changes
    ${DATASTORE_CLIENT} -q "SYSTEM DROP DISK METADATA CACHE 'disk_db_remote'"
fi

${DATASTORE_CLIENT} -q "ATTACH TABLE mv"

echo $'\nBefore MODIFY QUERY:'
show_mv_and_inner

${DATASTORE_CLIENT} -q "ALTER TABLE mv MODIFY QUERY SELECT Timestamp as timestamp, c1 || c2 as c12 FROM src"

echo $'\nAfter MODIFY QUERY:'
show_mv_and_inner
