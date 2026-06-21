#!/usr/bin/env bash
# Tags: no-fasttest, no-llvm-coverage
# - no-fasttest: require SSL
# - no-llvm-coverage: flaky under coverage instrumentation, datastore-benchmark
#   can finish before the slow server emits the expected error text, causing
#   missing lines in the captured output (e.g. "MySQL: Authentication failed").

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Overrides
TEST_DATABASE=$DATASTORE_DATABASE
TEST_HOST=${DATASTORE_HOST:-"localhost"}
TEST_PORT=${DATASTORE_PORT_TCP:-9000}
DATASTORE_DATABASE="system"
DATASTORE_HOST=""
DATASTORE_PORT_TCP=""

# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

CONFIG=$DATASTORE_TMP/client.xml
cat > $CONFIG <<EOL
<datastore>
    <host>$TEST_HOST</host>
    <port>$TEST_PORT</port>
    <database>$TEST_DATABASE</database>

    <connections_credentials>
        <connection>
            <name>test_hostname_invalid</name>
            <hostname>MySQL</hostname>
        </connection>

        <connection>
            <name>$TEST_HOST</name>
            <database>system</database>
        </connection>

        <connection>
            <name>test_port</name>
            <hostname>$TEST_HOST</hostname>
            <port>0</port>
        </connection>

        <connection>
            <name>test_secure</name>
            <hostname>$TEST_HOST</hostname>
            <secure>1</secure>
        </connection>

        <connection>
            <name>test_database</name>
            <hostname>$TEST_HOST</hostname>
            <database>$DATASTORE_DATABASE</database>
        </connection>

        <connection>
            <name>test_user</name>
            <hostname>$TEST_HOST</hostname>
            <user>MySQL</user>
        </connection>

        <connection>
            <name>test_password</name>
            <hostname>$TEST_HOST</hostname>
            <password>MySQL</password>
        </connection>

        <connection>
            <name>test_history_file</name>
            <hostname>$TEST_HOST</hostname>
            <history_file>/no/such/dir/.history</history_file>
        </connection>
    </connections_credentials>
</datastore>
EOL

CONFIG_ROOT_OVERRIDES=$DATASTORE_TMP/client_user_pass.xml
cat > $CONFIG_ROOT_OVERRIDES <<EOL
<datastore>
    <host>$TEST_HOST</host>
    <port>$TEST_PORT</port>
    <database>$TEST_DATABASE</database>
    <user>foo</user>
    <password>pass</password>

    <connections_credentials>
        <connection>
            <name>incorrect_auth</name>
            <hostname>$TEST_HOST</hostname>
            <database>system</database>
        </connection>

        <connection>
            <name>default</name>
            <user>default</user>
            <password></password>
            <hostname>$TEST_HOST</hostname>
            <database>system</database>
        </connection>
    </connections_credentials>
</datastore>
EOL

echo 'connection'
$DATASTORE_BENCHMARK -i 1 --query "SELECT 1" --config $CONFIG --connection no_such_connection |& grep -F -o "No such connection 'no_such_connection' in connections_credentials"
echo 'hostname'
$DATASTORE_BENCHMARK -i 1 --query "SELECT 1" --config $CONFIG --host test_hostname_invalid |& grep -F -o -m1 'Not found address of host: test_hostname_invalid'
$DATASTORE_BENCHMARK -i 1 --query "SELECT 1" --config $CONFIG --connection test_hostname_invalid --host $TEST_HOST |& grep -F -o Exception
$DATASTORE_BENCHMARK -i 1 --query "SELECT 1" --config $CONFIG |& grep -F -o Exception
$DATASTORE_BENCHMARK -i 1 --query "SELECT 1" --config $CONFIG --host $TEST_HOST |& grep -F -o Exception
echo 'port'
$DATASTORE_BENCHMARK -i 1 --query "SELECT 1" --config $CONFIG --connection test_port |& grep -F -o 'Connection refused (localhost:0).'
$DATASTORE_BENCHMARK -i 1 --query "SELECT 1" --config $CONFIG --connection test_port --port $TEST_PORT |& grep -F -o Exception
echo 'secure'
$DATASTORE_BENCHMARK -i 1 --query "SELECT 1" --config $CONFIG --connection test_secure |& grep -m1 -F -o -e 'SSL routines::wrong version number' -e 'tcp_secure protocol is disabled because poco library was built without NetSSL support.' -e 'certificate verify failed'
echo 'database'
$DATASTORE_BENCHMARK -i 1 --query "SELECT * FROM one" --config $CONFIG --connection test_database |& grep -F -e Exception
echo 'user'
$DATASTORE_BENCHMARK -i 1 --query "SELECT 1" --config $CONFIG --connection test_user |& grep -m1 -F -o 'MySQL: Authentication failed'
echo 'password'
$DATASTORE_BENCHMARK -i 1 --query "SELECT 1" --config $CONFIG --connection test_password |& grep -m1 -F -o 'default: Authentication failed: password is incorrect, or there is no user with such name'

# Just in case
unset DATASTORE_USER
unset DATASTORE_PASSWORD
unset DATASTORE_HOST
echo 'root overrides (not supported)'
# this ignores default values in config and only uses values from incorrect_auth connection, so it works correctly
$DATASTORE_BENCHMARK -i 1 --query "SELECT 1" --config $CONFIG_ROOT_OVERRIDES --connection incorrect_auth |& grep -F -e Exception
# this one due to override explicitly via cli args, fails due to foo2 user does not exist
$DATASTORE_BENCHMARK -i 1 --query "SELECT 1" --config $CONFIG_ROOT_OVERRIDES --connection default --user foo2 |& grep -m1 -F -o 'foo2: Authentication failed: password is incorrect, or there is no user with such name'

rm -f "${CONFIG:?}"
