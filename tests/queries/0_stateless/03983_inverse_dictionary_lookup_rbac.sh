#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

user="user_${DATASTORE_TEST_UNIQUE_NAME}"
table_name="table_${DATASTORE_TEST_UNIQUE_NAME}"
dict_name="dict_${DATASTORE_TEST_UNIQUE_NAME}"
db_name="${DATASTORE_DATABASE}"

${DATASTORE_CLIENT} -nm --query "
    DROP USER IF EXISTS ${user};
    DROP TABLE IF EXISTS ${table_name} SYNC;
    DROP DICTIONARY IF EXISTS ${dict_name};

    CREATE TABLE ${table_name}
    (
        id UInt64,
        value_id UInt64
    )
    ENGINE = MergeTree
    ORDER BY id;

    INSERT INTO ${table_name} VALUES (1, 1), (2, 2);

    CREATE DICTIONARY ${dict_name}
    (
        id UInt64,
        name String
    )
    PRIMARY KEY id
    SOURCE(NULL())
    LAYOUT(HASHED_ARRAY())
    LIFETIME(0);

    CREATE USER ${user} IDENTIFIED WITH no_password;
    GRANT SELECT ON ${db_name}.${table_name} TO ${user};
    GRANT dictGet ON ${db_name}.${dict_name} TO ${user};
"

# Ensure user doesn't have CREATE TEMPORARY TABLE privileges.
${DATASTORE_CLIENT} --user="${user}" -nm --query "
    SELECT count() FROM dictionary('${db_name}.${dict_name}'); -- { serverError ACCESS_DENIED }
"

# Baseline: optimization disabled should work.
${DATASTORE_CLIENT} --user="${user}" -nm --query "
    SELECT count()
    FROM ${db_name}.${table_name}
    WHERE dictGet('${db_name}.${dict_name}', 'name', value_id) = 'abc'
    SETTINGS enable_analyzer = 1, optimize_inverse_dictionary_lookup = 0;
"

# Regression check: with optimization enabled this used to fail with ACCESS_DENIED.
${DATASTORE_CLIENT} --user="${user}" -nm --query "
    SELECT count()
    FROM ${db_name}.${table_name}
    WHERE dictGet('${db_name}.${dict_name}', 'name', value_id) = 'abc'
    SETTINGS enable_analyzer = 1, optimize_inverse_dictionary_lookup = 1;
"

${DATASTORE_CLIENT} -nm --query "
    DROP USER IF EXISTS ${user};
    DROP TABLE IF EXISTS ${table_name} SYNC;
    DROP DICTIONARY IF EXISTS ${dict_name};
"
