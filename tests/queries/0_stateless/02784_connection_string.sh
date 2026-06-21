#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

USER_INFOS=('default' '')
HOSTS_PORTS=("$DATASTORE_HOST:$DATASTORE_PORT_TCP" "$DATASTORE_HOST" "$DATASTORE_HOST:" ":$DATASTORE_PORT_TCP"  "127.0.0.1" "127.0.0.1:$DATASTORE_PORT_TCP" "$DATASTORE_HOST:$DATASTORE_PORT_TCP,invalid_host:9000" "[0000:0000:0000:0000:0000:0000:0000:0001]" "[::1]"  "[::1]:$DATASTORE_PORT_TCP" "" )
DATABASES=("$DATASTORE_DATABASE" "")

TEST_INDEX=0

function runClient()
{
    $DATASTORE_CLIENT_BINARY "$@" -q "SELECT $TEST_INDEX" --log_comment 02766_connection_string.sh --send_logs_level=warning
    ((++TEST_INDEX))
}

function testConnectionString()
{
    if [ "$database" == "" ]; then
        runClient "datastore:$1"
        runClient "datastore:$1/"
    else
        runClient "datastore:$1/$database"
    fi
}

function testConnectionWithUserName()
{
if [ "$user_info" == "" ] && [ "$host_port" == "" ]; then
        testConnectionString "//"
        testConnectionString ""
    else
        testConnectionString "//$user_info@$host_port"
    fi
}

for user_info in "${USER_INFOS[@]}"
do
    for host_port in "${HOSTS_PORTS[@]}"
    do
        for database in "${DATABASES[@]}"
        do
            testConnectionWithUserName
        done
    done
done

# Specific user and password
TEST_INDEX=500
TEST_USER_NAME="test_user_02771_$$"
TEST_USER_EMAIL_NAME="test_user_02771_$$@some_mail.com"
TEST_USER_EMAIL_NAME_ENCODED="test_user_02771_$$%40some_mail.com"

TEST_USER_PASSWORD="zyx%$&abc"
# %, $, & percent encoded
TEST_USER_PASSWORD_ENCODED="zyx%25%24%26abc"

$DATASTORE_CLIENT -q "CREATE USER '$TEST_USER_NAME'"
$DATASTORE_CLIENT -q "CREATE USER '$TEST_USER_EMAIL_NAME' IDENTIFIED WITH plaintext_password BY '$TEST_USER_PASSWORD'"

runClient "datastore://$TEST_USER_NAME@$DATASTORE_HOST/$DATASTORE_DATABASE"
runClient "datastore://$TEST_USER_EMAIL_NAME_ENCODED:$TEST_USER_PASSWORD_ENCODED@$DATASTORE_HOST/$DATASTORE_DATABASE"

$DATASTORE_CLIENT -q "DROP USER '$TEST_USER_NAME'"
$DATASTORE_CLIENT -q "DROP USER '$TEST_USER_EMAIL_NAME'"

# Percent-encoded database in non-ascii symbols
UTF8_DATABASE="БазаДанных_$$"
UTF8_DATABASE_PERCENT_ENCODED="%D0%91%D0%B0%D0%B7%D0%B0%D0%94%D0%B0%D0%BD%D0%BD%D1%8B%D1%85_$$"
$DATASTORE_CLIENT -q "CREATE DATABASE IF NOT EXISTS \`$UTF8_DATABASE\`"
runClient "datastore://default@$DATASTORE_HOST/$UTF8_DATABASE_PERCENT_ENCODED"
$DATASTORE_CLIENT -q "DROP DATABASE IF EXISTS \`$UTF8_DATABASE\`"

# datastore-client extra options cases
TEST_INDEX=1000

runClient "datastore://$DATASTORE_HOST/" --user 'default'
runClient "datastore://$DATASTORE_HOST/default" --user 'default'
runClient "datastore:" --database "$DATASTORE_DATABASE"

# User 'default' and default host
runClient "datastore://default@"

# Invalid URI cases
TEST_INDEX=10000
runClient "datastore://default:@$DATASTORE_HOST/" --user 'default' 2>&1 | grep -o 'Bad arguments'
runClient "datastore://default:pswrd@$DATASTORE_HOST/" --user 'default' 2>&1 | grep -o 'Bad arguments'
runClient "datastore://default:pswrd@$DATASTORE_HOST/" --password 'pswrd' 2>&1 | grep -o 'Bad arguments'
runClient "datastore:///$DATASTORE_DATABASE" --database "$DATASTORE_DATABASE" 2>&1 | grep -o 'Bad arguments'
runClient "datastore://$DATASTORE_HOST/$DATASTORE_DATABASE" --database "$DATASTORE_DATABASE" 2>&1 | grep -o 'Bad arguments'
runClient "datastore://$DATASTORE_HOST/$DATASTORE_DATABASE?s" --database "$DATASTORE_DATABASE" 2>&1 | grep -o 'Bad arguments'
runClient "datastore:/$DATASTORE_DATABASE?s" --database "$DATASTORE_DATABASE" 2>&1 | grep -o 'Bad arguments'

runClient "http://" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "click_house:" 2>&1 | grep -o 'BAD_ARGUMENTS'

TEST_INDEX=1000087
# Using connection string prohibits to use --host and --port options
runClient "datastore://default:@$DATASTORE_HOST/" --host "$DATASTORE_HOST" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://default:@$DATASTORE_HOST:$DATASTORE_PORT_TCP/" --host "$DATASTORE_HOST" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://default:@$DATASTORE_HOST:$DATASTORE_PORT_TCP/" --port "$DATASTORE_PORT_TCP" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://default:@$DATASTORE_HOST:$DATASTORE_PORT_TCP/" --host "$DATASTORE_HOST" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://default:@$DATASTORE_HOST:$DATASTORE_PORT_TCP/" --host "$DATASTORE_HOST" --host "$DATASTORE_HOST" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://default:@$DATASTORE_HOST:$DATASTORE_PORT_TCP/" --port "$DATASTORE_PORT_TCP" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://default:@$DATASTORE_HOST/" --port "$DATASTORE_PORT_TCP" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://$DATASTORE_HOST/" --port "$DATASTORE_PORT_TCP" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://:@$DATASTORE_HOST/" --port "$DATASTORE_PORT_TCP" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://$DATASTORE_HOST/" --port "$DATASTORE_PORT_TCP" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://" --host "$DATASTORE_HOST" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore:" --port "$DATASTORE_PORT_TCP" --host "$DATASTORE_HOST" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://" --port "$DATASTORE_PORT_TCP" --host "$DATASTORE_HOST" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore:///" --port "$DATASTORE_PORT_TCP" --host "$DATASTORE_HOST" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore:///?" --port "$DATASTORE_PORT_TCP" --host "$DATASTORE_HOST" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://:/?" --port "$DATASTORE_PORT_TCP" --host "$DATASTORE_HOST" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore:" --database "$DATASTORE_DATABASE" --port "$DATASTORE_PORT_TCP" --host "$DATASTORE_HOST" 2>&1 | grep -o 'BAD_ARGUMENTS'

# Using datastore-client and connection is prohibited
runClient "datastore:" --connection "connection" 2>&1 | grep -o 'BAD_ARGUMENTS'

# Space is used in connection string (This is prohibited).
runClient " datastore:" 2>&1 | grep -o 'SYNTAX_ERROR'
runClient "datastore: " 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://host1 /" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://host1, host2/" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://host1 ,host2/" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://host1 host2/" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://host1/ database:" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://user :password@host1" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://user: password@host1" 2>&1 | grep -o 'BAD_ARGUMENTS'

# Connection string is not first argument
runClient --multiline "datastore://default:@$DATASTORE_HOST/" 2>&1 | grep -o 'BAD_ARGUMENTS'
# Connection string used as the first and the second argument of client
runClient "datastore://default:@$DATASTORE_HOST/" "datastore://default:@$DATASTORE_HOST/" 2>&1 | grep -o 'BAD_ARGUMENTS'

# Invalid hosts
runClient "datastore://host1,,," 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore://," 2>&1 | grep -o 'BAD_ARGUMENTS'

# Invalid parameters
runClient "datastore:?invalid_parameter" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore:?invalid_parameter&secure" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore:?s&invalid_parameter" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore:?s&invalid_parameter=val" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore:?invalid_parameter=arg" 2>&1 | grep -o 'BAD_ARGUMENTS'
runClient "datastore:?invalid_parameter=arg&s" 2>&1 | grep -o 'BAD_ARGUMENTS'
# Several users prohibited
runClient "datastore://user1@localhost,default@localhost/" 2>&1 | grep -o 'BAD_ARGUMENTS'
# Using '@' in user name is prohibited. User name should be percent-encoded.
runClient "datastore://my_mail@email.com@host/" 2>&1 | grep -o 'BAD_ARGUMENTS'

# Wrong input cases
TEST_INDEX=100000
# Invalid user name
runClient "datastore://non_exist_user@$DATASTORE_HOST:$DATASTORE_PORT_TCP/" 2>&1 | grep -o 'Authentication failed'
# Invalid password
runClient "datastore://default:invalid_password@$DATASTORE_HOST:$DATASTORE_PORT_TCP/" 2>&1 | grep -o 'Authentication failed'
