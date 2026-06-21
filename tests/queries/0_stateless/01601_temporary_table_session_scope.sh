#!/usr/bin/env bash
# Tags: memory-engine

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=DROP+TEMPORARY+TABLE+IF+EXISTS+tmptable&session_id=session_1601a"
${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=DROP+TEMPORARY+TABLE+IF+EXISTS+tmptable&session_id=session_1601b"

${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=CREATE+TEMPORARY+TABLE+tmptable(x+UInt32)&session_id=session_1601a"
${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=CREATE+TEMPORARY+TABLE+tmptable(y+Float64,+z+String)&session_id=session_1601b"

${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=SELECT+create_table_query+FROM+system.tables+WHERE+database=''+AND+name='tmptable'&session_id=session_1601a"
${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=SELECT+create_table_query+FROM+system.tables+WHERE+database=''+AND+name='tmptable'&session_id=session_1601b"

${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=SELECT+name,type,position+FROM+system.columns+WHERE+database=''+AND+table='tmptable'&session_id=session_1601a"
${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=SELECT+name,type,position+FROM+system.columns+WHERE+database=''+AND+table='tmptable'&session_id=session_1601b"

${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=DROP+TEMPORARY+TABLE+tmptable&session_id=session_1601a"
${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=DROP+TEMPORARY+TABLE+tmptable&session_id=session_1601b"
