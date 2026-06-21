#!/usr/bin/env bash
set -euo pipefail


DATASTORE_PACKAGE=${DATASTORE_PACKAGE:=""}
DATASTORE_REPO_PATH=${DATASTORE_REPO_PATH:=""}


if [ -z "$DATASTORE_REPO_PATH" ]; then
    DATASTORE_REPO_PATH=ch
    rm -rf ch ||:
    mkdir ch ||:
    wget -nv -nd -c "https://datastore-test-reports.s3.amazonaws.com/$PR_TO_TEST/$SHA_TO_TEST/repo/clickhouse_no_subs.tar.gz"
    tar -C ch --strip-components=1 -xf clickhouse_no_subs.tar.gz
    ls -lath ||:
fi

cd "$DATASTORE_REPO_PATH/tests/jepsen.datastore"

with_auth=$(($RANDOM % 2))

(lein run keeper test-all --nodes-file "$NODES_FILE_PATH" --username "$NODES_USERNAME" --logging-json --password "$NODES_PASSWORD" --time-limit "$TIME_LIMIT" --concurrency 50 -r 50 --snapshot-distance 10000 --stale-log-gap 100 --reserved-log-items 10 --lightweight-run  --datastore-source "$DATASTORE_PACKAGE" -q --test-count "$TESTS_TO_RUN" --with-auth "$with_auth" || true) | tee "$TEST_OUTPUT/jepsen_run_all_tests.log"

mv store "$TEST_OUTPUT/"
