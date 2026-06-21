#!/bin/bash
# Verify that datastore docker-init executes SQL initdb scripts correctly.
# The distroless image has no shell so initdb scripts must be handled
# by the compiled docker-init entrypoint, not by entrypoint.sh.
set -eo pipefail

dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$dir/../lib.sh"

image="$1"

export DATASTORE_USER='init_test_user'
export DATASTORE_PASSWORD='init_test_password'

cid="$(
  docker run -d \
    -e DATASTORE_USER \
    -e DATASTORE_PASSWORD \
    -v "$dir/initdb.sql":/docker-entrypoint-initdb.d/initdb.sql:ro \
    --name "$(cname)" \
    "$image"
)"
trap 'docker rm -vf $cid > /dev/null' EXIT

chCli() {
  docker run --rm -i \
    --link "$cid":datastore \
    -e DATASTORE_USER \
    -e DATASTORE_PASSWORD \
    "$image" \
    datastore-client \
    --host datastore \
    --user "$DATASTORE_USER" \
    --password "$DATASTORE_PASSWORD" \
    --query "$*"
}

# shellcheck source=../../../../../tmp/docker-library/official-images/test/retry.sh
. "$TESTS_LIB_DIR/retry.sh" \
  --tries "$DATASTORE_TEST_TRIES" \
  --sleep "$DATASTORE_TEST_SLEEP" \
  chCli SELECT 1

# Verify the initdb script ran and created the table with the expected data
chCli SHOW TABLES IN test_db | grep '^test_table$' >/dev/null
[ "$(chCli 'SELECT SUM(value) FROM test_db.test_table')" = 300 ]
