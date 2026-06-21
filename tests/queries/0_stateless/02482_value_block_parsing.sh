#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} --query="
  CREATE TABLE simple_key_dictionary_source_table__fuzz_48
  (
      id Nullable(Int8),
      value Array(Date),
      value_nullable UUID
  )
  ENGINE = TinyLog;"

echo "INSERT INTO simple_key_dictionary_source_table__fuzz_48 FORMAT Values (null, [], '61f0c404-5cb3-11e7-907b-a6006ad3dba0')
( -- Bu        " | ${DATASTORE_CURL} -s "${DATASTORE_URL}" --data-binary @- -v 2>&1 | grep -c 'X-Datastore-Exception-Code: 62'


echo "INSERT INTO simple_key_dictionary_source_table__fuzz_48 FORMAT Values
                  (!Invalid" | ${DATASTORE_CURL} -s "${DATASTORE_URL}" --data-binary @- -v 2>&1 | grep -c 'X-Datastore-Exception-Code: 62'

echo "INSERT INTO simple_key_dictionary_source_table__fuzz_48 FORMAT Values    (null, [], '61f0c404-5cb3-11e7-907b-a6006ad3dba0')
          ,(null, [], '61f0c404-5cb3-11e7-907b-a6006ad3dba0'),
          (!!!!!!3adas
      )" | ${DATASTORE_CURL} -s "${DATASTORE_URL}" --data-binary @- -v 2>&1  | grep -c 'X-Datastore-Exception-Code: 62'
