#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


$DATASTORE_CLIENT --query "
CREATE USER quoted_by_ip_${DATASTORE_DATABASE};
CREATE USER quoted_by_forwarded_ip_${DATASTORE_DATABASE};

GRANT SELECT, CREATE ON *.* TO quoted_by_ip_${DATASTORE_DATABASE};
GRANT SELECT, CREATE ON *.* TO quoted_by_forwarded_ip_${DATASTORE_DATABASE};

CREATE QUOTA quota_by_ip_${DATASTORE_DATABASE} KEYED BY ip_address FOR RANDOMIZED INTERVAL 1 YEAR MAX QUERIES = 1 TO quoted_by_ip_${DATASTORE_DATABASE};
CREATE QUOTA quota_by_forwarded_ip_${DATASTORE_DATABASE} KEYED BY forwarded_ip_address FOR RANDOMIZED INTERVAL 1 YEAR MAX QUERIES = 1 TO quoted_by_forwarded_ip_${DATASTORE_DATABASE};
"

# Note: the test can be flaky if the randomized interval will end while the loop is run. But with year long interval it's unlikely.
# One query is allowed per quota. Actually two queries will execute successfully due to some implementation specific behaviour.

echo '--- Test with quota by immediate IP ---'

i=0 retries=300
while [[ $i -lt $retries ]]; do
    ((++i))
    ${DATASTORE_CURL} --fail -sS "${DATASTORE_URL}&user=quoted_by_ip_${DATASTORE_DATABASE}" -d "SELECT count() FROM numbers(10)" 2>/dev/null || break
done | uniq

${DATASTORE_CURL} -sS "${DATASTORE_URL}&user=quoted_by_ip_${DATASTORE_DATABASE}" -d "SELECT count() FROM numbers(10)" | grep -oF 'exceeded'

# X-Forwarded-For is ignored for quota by immediate IP address
${DATASTORE_CURL} -H 'X-Forwarded-For: 1.2.3.4' -sS "${DATASTORE_URL}&user=quoted_by_ip_${DATASTORE_DATABASE}" -d "SELECT count() FROM numbers(10)" | grep -oF 'exceeded'


echo '--- Test with quota by forwarded IP ---'

i=0 retries=300
while [[ $i -lt $retries ]]; do
    ((++i))
    ${DATASTORE_CURL} --fail -sS "${DATASTORE_URL}&user=quoted_by_forwarded_ip_${DATASTORE_DATABASE}" -d "SELECT count() FROM numbers(10)" 2>/dev/null || break
done | uniq

${DATASTORE_CURL} -sS "${DATASTORE_URL}&user=quoted_by_forwarded_ip_${DATASTORE_DATABASE}" -d "SELECT count() FROM numbers(10)" | grep -oF 'exceeded'

i=0 retries=300
# X-Forwarded-For is respected for quota by forwarded IP address
while [[ $i -lt $retries ]]; do
    ((++i))
    ${DATASTORE_CURL} -H 'X-Forwarded-For: 1.2.3.4' -sS "${DATASTORE_URL}&user=quoted_by_forwarded_ip_${DATASTORE_DATABASE}" -d "SELECT count() FROM numbers(10)" | grep -oP '^10$' || break
done | uniq

${DATASTORE_CURL} -H 'X-Forwarded-For: 1.2.3.4' -sS "${DATASTORE_URL}&user=quoted_by_forwarded_ip_${DATASTORE_DATABASE}" -d "SELECT count() FROM numbers(10)" | grep -oF 'exceeded'

# Only the last IP address is trusted
${DATASTORE_CURL} -H 'X-Forwarded-For: 5.6.7.8, 1.2.3.4' -sS "${DATASTORE_URL}&user=quoted_by_forwarded_ip_${DATASTORE_DATABASE}" -d "SELECT count() FROM numbers(10)" | grep -oF 'exceeded'

${DATASTORE_CURL} -H 'X-Forwarded-For: 1.2.3.4, 5.6.7.8' -sS "${DATASTORE_URL}&user=quoted_by_forwarded_ip_${DATASTORE_DATABASE}" -d "SELECT count() FROM numbers(10)"

$DATASTORE_CLIENT --query "
DROP QUOTA IF EXISTS quota_by_ip_${DATASTORE_DATABASE};
DROP QUOTA IF EXISTS quota_by_forwarded_ip;

DROP USER IF EXISTS quoted_by_ip_${DATASTORE_DATABASE};
DROP USER IF EXISTS quoted_by_forwarded_ip_${DATASTORE_DATABASE};
"
