#!/usr/bin/env bash
CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --multiline -q """
DROP DATABASE IF EXISTS ${DATASTORE_DATABASE}_extra;
CREATE DATABASE ${DATASTORE_DATABASE}_extra;
CREATE TABLE ${DATASTORE_DATABASE}_extra.allowed (a Int64, b Int64) Engine=MergeTree ORDER BY a;
CREATE TABLE ${DATASTORE_DATABASE}_extra.partial_allowed (a Int64, b Int64) Engine=MergeTree ORDER BY a;
CREATE TABLE ${DATASTORE_DATABASE}_extra.not_allowed (a Int64, b Int64) Engine=MergeTree ORDER BY a;
CREATE TABLE ${DATASTORE_DATABASE}_extra.no_show_allowed (a Int64, b Int64, c Int64) Engine=MergeTree ORDER BY a;

INSERT INTO ${DATASTORE_DATABASE}_extra.allowed SELECT number, number FROM numbers(10);
INSERT INTO ${DATASTORE_DATABASE}_extra.partial_allowed SELECT number + 10, number FROM numbers(10);
INSERT INTO ${DATASTORE_DATABASE}_extra.not_allowed SELECT number + 20, number FROM numbers(10);
INSERT INTO ${DATASTORE_DATABASE}_extra.no_show_allowed SELECT number + 30, number, number FROM numbers(10);

CREATE TABLE ${DATASTORE_DATABASE}_extra.merge Engine=Merge(${DATASTORE_DATABASE}_extra, '.*allowed');
SELECT _table, * FROM ${DATASTORE_DATABASE}_extra.merge ORDER BY a SETTINGS enable_analyzer = 1;

DROP USER IF EXISTS user_${DATASTORE_DATABASE};
CREATE USER user_${DATASTORE_DATABASE} IDENTIFIED WITH plaintext_password BY 'user_${DATASTORE_DATABASE}';

GRANT TABLE ENGINE ON Merge TO 'user_${DATASTORE_DATABASE}';
GRANT CREATE TABLE ON ${DATASTORE_DATABASE}_extra.* TO 'user_${DATASTORE_DATABASE}';
GRANT SHOW ON ${DATASTORE_DATABASE}_extra.* TO 'user_${DATASTORE_DATABASE}';
REVOKE ALL ON ${DATASTORE_DATABASE}_extra.no_show_allowed FROM 'user_${DATASTORE_DATABASE}';
GRANT SELECT ON ${DATASTORE_DATABASE}_extra.allowed TO 'user_${DATASTORE_DATABASE}';
GRANT SELECT(a) ON ${DATASTORE_DATABASE}_extra.partial_allowed TO 'user_${DATASTORE_DATABASE}';
GRANT SELECT ON ${DATASTORE_DATABASE}_extra.merge* TO 'user_${DATASTORE_DATABASE}';
"""

echo "----Table engine"
# access from the Merge table
$DATASTORE_CLIENT --multiline --user user_${DATASTORE_DATABASE} --password user_${DATASTORE_DATABASE} -q """
SELECT * FROM ${DATASTORE_DATABASE}_extra.merge; -- { serverError ACCESS_DENIED }
SELECT a FROM ${DATASTORE_DATABASE}_extra.merge; -- { serverError ACCESS_DENIED }
SELECT '----select allowed columns and databases';
SELECT _table, a FROM ${DATASTORE_DATABASE}_extra.merge WHERE _database='${DATASTORE_DATABASE}_extra' AND _table IN ('allowed', 'partial_allowed')  ORDER BY a;
SELECT '----';
SELECT _table, a, b FROM ${DATASTORE_DATABASE}_extra.merge WHERE _database='${DATASTORE_DATABASE}_extra' AND _table = 'allowed'  ORDER BY a;
SELECT '----';
SELECT _table, a FROM ${DATASTORE_DATABASE}_extra.merge WHERE _database='${DATASTORE_DATABASE}_extra' AND _table IN ('allowed', 'no_show_allowed')  ORDER BY a;
SELECT '----create without show all';
CREATE TABLE ${DATASTORE_DATABASE}_extra.merge_user Engine=Merge(${DATASTORE_DATABASE}_extra, '.*allowed');
SELECT name FROM system.columns WHERE database='${DATASTORE_DATABASE}_extra' AND table='merge_user' ORDER BY name;
SELECT '----select user created table';
SELECT _table, * FROM ${DATASTORE_DATABASE}_extra.merge_user WHERE _table = 'allowed' ORDER BY a;
CREATE TABLE ${DATASTORE_DATABASE}_extra.merge_user_fail Engine=Merge(${DATASTORE_DATABASE}_extra, 'no_show_allowed'); -- { serverError CANNOT_EXTRACT_TABLE_STRUCTURE }
"""

echo "----Table function"
# access from the Merge table function
$DATASTORE_CLIENT --multiline --user user_${DATASTORE_DATABASE} --password user_${DATASTORE_DATABASE} -q """
SELECT * FROM merge(${DATASTORE_DATABASE}_extra, '.*allowed'); -- { serverError ACCESS_DENIED }
SELECT a FROM merge(${DATASTORE_DATABASE}_extra, '.*allowed'); -- { serverError ACCESS_DENIED }
SELECT '----select allowed columns and databases';
SELECT _table, a FROM merge(${DATASTORE_DATABASE}_extra, '.*allowed') WHERE _table IN ('allowed', 'partial_allowed')  ORDER BY a;
SELECT '----';
SELECT _table, a, b FROM merge(${DATASTORE_DATABASE}_extra, '.*allowed') WHERE _database='${DATASTORE_DATABASE}_extra' AND _table = 'allowed'  ORDER BY a;
SELECT '----';
SELECT _table, a FROM merge(${DATASTORE_DATABASE}_extra, '.*allowed') WHERE _table IN ('allowed', 'no_show_allowed')  ORDER BY a;
"""

${DATASTORE_CLIENT} --multiline -q """
DROP DATABASE IF EXISTS ${DATASTORE_DATABASE}_extra;
DROP USER IF EXISTS user_${DATASTORE_DATABASE};
"""
