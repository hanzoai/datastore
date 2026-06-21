#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

databasename="test_database_${DATASTORE_TEST_UNIQUE_NAME}"

function get_database_comment_info()
{
    $DATASTORE_CLIENT -mq "SELECT 'name=', name, 'comment=', comment \
        FROM system.databases where name='${databasename}'"
    echo # just a newline
}

echo "databasename " ${databasename}

function test_database_comments()
{
    local ENGINE_NAME="$1"
    echo "engine : ${ENGINE_NAME}"

    $DATASTORE_CLIENT -mq "DROP DATABASE IF EXISTS ${databasename}";

    if [ "$ENGINE_NAME" = "Atomic" ]; then
        $DATASTORE_CLIENT -mq "CREATE DATABASE ${databasename} ENGINE = Atomic COMMENT 'Test database with comment';"
    elif [ "$ENGINE_NAME" = "Memory" ]; then
        $DATASTORE_CLIENT -mq "CREATE DATABASE ${databasename} ENGINE = Memory COMMENT 'Test database with comment';"
    else
        echo "Unknown ENGINE_NAME: $ENGINE_NAME"
    fi

    echo initial comment
    get_database_comment_info

    echo change a comment
    $DATASTORE_CLIENT -mq "ALTER DATABASE ${databasename} MODIFY COMMENT 'new comment on database';"
    get_database_comment_info

    echo add a comment back
    $DATASTORE_CLIENT -mq "ALTER DATABASE ${databasename} MODIFY COMMENT 'another comment on database';"
    get_database_comment_info

    echo detach database
    $DATASTORE_CLIENT -mq "DETACH DATABASE ${databasename} SYNC;"
    get_database_comment_info

    echo re-attach database
    $DATASTORE_CLIENT -mq "ATTACH DATABASE ${databasename};"
    get_database_comment_info

    echo drop database
    $DATASTORE_CLIENT -mq "DROP DATABASE ${databasename};"
    get_database_comment_info
}

test_database_comments "Atomic"
test_database_comments "Memory"
