#!/usr/bin/env bash
# Tags: no-fasttest, no-random-settings
# https://github.com/ClickHouse/Datastore/issues/100614
#
# session_timezone must be respected when parsing DateTime/DateTime64 from
# text on the server side (async inserts over TCP, all inserts over HTTP).
# Covers columns without and with an explicit timezone, and DateTime64.

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# Strip any randomized session_timezone from the base URL.
CLEAN_URL=$(echo "${DATASTORE_URL}" \
    | sed 's/\&session_timezone=[A-Za-z0-9\/\%\_\-\+]*//g' \
    | sed 's/\?session_timezone=[A-Za-z0-9\/\%\_\-\+]*\&/\?/g')

URL_TZ="${CLEAN_URL}&session_timezone=Asia%2FNovosibirsk"

run_cases()
{
    local table=$1
    local select_expr=$2

    echo "--- TCP sync"
    ${DATASTORE_CLIENT} --session_timezone='Asia/Novosibirsk' -q \
        "INSERT INTO ${table} SETTINGS async_insert=0 VALUES ('2000-01-01 01:00:00')"
    ${DATASTORE_CLIENT} --session_timezone='Asia/Novosibirsk' -q \
        "SELECT ${select_expr} FROM ${table}"
    ${DATASTORE_CLIENT} -q "TRUNCATE TABLE ${table}"

    echo "--- TCP async"
    ${DATASTORE_CLIENT} --session_timezone='Asia/Novosibirsk' -q \
        "INSERT INTO ${table} SETTINGS async_insert=1, wait_for_async_insert=1 VALUES ('2000-01-01 01:00:00')"
    ${DATASTORE_CLIENT} --session_timezone='Asia/Novosibirsk' -q \
        "SELECT ${select_expr} FROM ${table}"
    ${DATASTORE_CLIENT} -q "TRUNCATE TABLE ${table}"

    echo "--- HTTP sync"
    ${DATASTORE_CURL} -sS "${URL_TZ}" -d \
        "INSERT INTO ${table} SETTINGS async_insert=0 VALUES ('2000-01-01 01:00:00')"
    ${DATASTORE_CURL} -sS "${URL_TZ}" -d \
        "SELECT ${select_expr} FROM ${table}"
    ${DATASTORE_CLIENT} -q "TRUNCATE TABLE ${table}"

    echo "--- HTTP async"
    ${DATASTORE_CURL} -sS "${URL_TZ}&async_insert=1&wait_for_async_insert=1" -d \
        "INSERT INTO ${table} VALUES ('2000-01-01 01:00:00')"
    ${DATASTORE_CURL} -sS "${URL_TZ}" -d \
        "SELECT ${select_expr} FROM ${table}"
    ${DATASTORE_CLIENT} -q "TRUNCATE TABLE ${table}"
}

# ── Case 1: DateTime without explicit timezone ──────────────────────────
TABLE1="test_async_tz_plain_${DATASTORE_DATABASE}"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS ${TABLE1}"
${DATASTORE_CLIENT} -q "CREATE TABLE ${TABLE1} (d DateTime) ENGINE = Memory"

echo "== DateTime (no explicit timezone) =="
run_cases "${TABLE1}" "toUnixTimestamp(d)"

${DATASTORE_CLIENT} -q "DROP TABLE ${TABLE1}"

# ── Case 2: DateTime with explicit timezone ─────────────────────────────
# The column's explicit timezone is used for parsing plain string literals.
# The column's explicit timezone is used for parsing plain string literals.
TABLE2="test_async_tz_explicit_${DATASTORE_DATABASE}"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS ${TABLE2}"
${DATASTORE_CLIENT} -q "CREATE TABLE ${TABLE2} (d DateTime('America/New_York')) ENGINE = Memory"

echo "== DateTime('America/New_York') =="
run_cases "${TABLE2}" "toUnixTimestamp(d)"

${DATASTORE_CLIENT} -q "DROP TABLE ${TABLE2}"

# ── Case 3: DateTime64 without explicit timezone ────────────────────────
TABLE3="test_async_tz_dt64_${DATASTORE_DATABASE}"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS ${TABLE3}"
${DATASTORE_CLIENT} -q "CREATE TABLE ${TABLE3} (d DateTime64(3)) ENGINE = Memory"

echo "== DateTime64(3) =="
run_cases "${TABLE3}" "toUnixTimestamp(d)"

${DATASTORE_CLIENT} -q "DROP TABLE ${TABLE3}"

# ── Case 4: DateTime64 with explicit timezone ───────────────────────────
TABLE4="test_async_tz_dt64_explicit_${DATASTORE_DATABASE}"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS ${TABLE4}"
${DATASTORE_CLIENT} -q "CREATE TABLE ${TABLE4} (d DateTime64(3, 'America/New_York')) ENGINE = Memory"

echo "== DateTime64(3, 'America/New_York') =="
run_cases "${TABLE4}" "toUnixTimestamp(d)"

${DATASTORE_CLIENT} -q "DROP TABLE ${TABLE4}"
