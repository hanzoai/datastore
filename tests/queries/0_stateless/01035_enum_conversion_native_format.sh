#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

${DATASTORE_CLIENT} --query="drop table if exists enum_source;"
${DATASTORE_CLIENT} --query="drop table if exists enum_buf;"

${DATASTORE_CLIENT} --query="create table enum_source(e Enum8('a'=1)) engine = MergeTree order by tuple()"
${DATASTORE_CLIENT} --query="insert into enum_source values ('a')"
${DATASTORE_CLIENT} --query="create table enum_buf engine = Log as select * from enum_source;"
${DATASTORE_CLIENT} --query="alter table enum_source modify column e Enum8('a'=1, 'b'=2);"

${DATASTORE_CLIENT} --query="select * from enum_buf format Native" \
    | ${DATASTORE_CLIENT} --query="insert into enum_source format Native"

${DATASTORE_CLIENT} --query="select * from enum_source;"

${DATASTORE_CLIENT} --query="drop table enum_source;"
${DATASTORE_CLIENT} --query="drop table enum_buf;"
