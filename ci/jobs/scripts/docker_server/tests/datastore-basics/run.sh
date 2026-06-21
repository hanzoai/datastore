#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$dir/../lib.sh"

image="$1"

export DATASTORE_USER='my_cool_ch_user'
export DATASTORE_PASSWORD='my cool datastore password'

cid="$(
  docker run -d \
    -e DATASTORE_USER \
    -e DATASTORE_PASSWORD \
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

chCli SHOW DATABASES | grep '^system$' >/dev/null
