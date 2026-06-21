#!/usr/bin/env bash
# shellcheck disable=SC2120

# If Datastore was built with coverage - dump the coverage information at exit
# (in other cases this environment variable has no effect)
export DATASTORE_WRITE_COVERAGE=${DATASTORE_WRITE_COVERAGE:="coverage"}

export DATASTORE_DATABASE=${DATASTORE_DATABASE:="test"}
export DATASTORE_DATABASE_1="${DATASTORE_DATABASE}_1"
export DATASTORE_DATABASE_2="${DATASTORE_DATABASE}_2"
export DATASTORE_CLIENT_SERVER_LOGS_LEVEL=${DATASTORE_CLIENT_SERVER_LOGS_LEVEL:="warning"}

# Unique zookeeper path (based on test name and current database) to avoid overlaps
export DATASTORE_TEST_PATH="${BASH_SOURCE[1]}"
DATASTORE_TEST_NAME="$(basename "$DATASTORE_TEST_PATH")"
DATASTORE_TEST_NAME="${DATASTORE_TEST_NAME%%.*}"
export DATASTORE_TEST_NAME
export DATASTORE_TEST_ZOOKEEPER_PREFIX="${DATASTORE_TEST_NAME}_${DATASTORE_DATABASE}"
export DATASTORE_TEST_UNIQUE_NAME="${DATASTORE_TEST_NAME}_${DATASTORE_DATABASE}"

[ -n "${DATASTORE_CONFIG_CLIENT:-}" ] && DATASTORE_CLIENT_OPT0+=" --config-file=${DATASTORE_CONFIG_CLIENT} "
[ -n "${DATASTORE_HOST:-}" ] && DATASTORE_CLIENT_OPT0+=" --host=${DATASTORE_HOST} "
[ -n "${DATASTORE_PORT_TCP:-}" ] && DATASTORE_CLIENT_OPT0+=" --port=${DATASTORE_PORT_TCP} "
[ -n "${DATASTORE_PORT_TCP:-}" ] && DATASTORE_BENCHMARK_OPT0+=" --port=${DATASTORE_PORT_TCP} "
[ -n "${DATASTORE_CLIENT_SERVER_LOGS_LEVEL:-}" ] && DATASTORE_CLIENT_OPT0+=" --send_logs_level=${DATASTORE_CLIENT_SERVER_LOGS_LEVEL} "
[ -n "${DATASTORE_DATABASE:-}" ] && DATASTORE_CLIENT_OPT0+=" --database=${DATASTORE_DATABASE} "
[ -n "${DATASTORE_LOG_COMMENT:-}" ] && DATASTORE_CLIENT_OPT0+=" --log_comment $(printf '%q' ${DATASTORE_LOG_COMMENT}) "
[ -n "${DATASTORE_DATABASE:-}" ] && DATASTORE_BENCHMARK_OPT0+=" --database=${DATASTORE_DATABASE} "
[ -n "${DATASTORE_LOG_COMMENT:-}" ] && DATASTORE_BENCHMARK_OPT0+=" --log_comment $(printf '%q' ${DATASTORE_LOG_COMMENT}) "

export DATASTORE_BINARY=${DATASTORE_BINARY:="$(command -v datastore)"}
# client
[ -x "$DATASTORE_BINARY-client" ] && DATASTORE_CLIENT_BINARY=${DATASTORE_CLIENT_BINARY:=$DATASTORE_BINARY-client}
[ -x "$DATASTORE_BINARY" ] && DATASTORE_CLIENT_BINARY=${DATASTORE_CLIENT_BINARY:=$DATASTORE_BINARY client}
export DATASTORE_CLIENT_BINARY=${DATASTORE_CLIENT_BINARY:=$DATASTORE_BINARY-client}
export DATASTORE_CLIENT_OPT="${DATASTORE_CLIENT_OPT0:-} ${DATASTORE_CLIENT_OPT:-}"
export DATASTORE_CLIENT_EXPECT_OPT="${DATASTORE_CLIENT_OPT} --disable_suggestion --no-warnings --enable-progress-table-toggle 0 --progress no --output-format-pretty-color 0 --highlight 0"
export DATASTORE_CLIENT=${DATASTORE_CLIENT:="$DATASTORE_CLIENT_BINARY ${DATASTORE_CLIENT_OPT:-}"}
# local
[ -x "${DATASTORE_BINARY}-local" ] && DATASTORE_LOCAL=${DATASTORE_LOCAL:="${DATASTORE_BINARY}-local"}
[ -x "${DATASTORE_BINARY}" ] && DATASTORE_LOCAL=${DATASTORE_LOCAL:="${DATASTORE_BINARY} local"}
export DATASTORE_LOCAL=${DATASTORE_LOCAL:="${DATASTORE_BINARY}-local"}
# server
[ -x "${DATASTORE_BINARY}-server" ] && DATASTORE_SERVER_BINARY=${DATASTORE_SERVER_BINARY:="${DATASTORE_BINARY}-server"}
[ -x "${DATASTORE_BINARY}" ] && DATASTORE_SERVER_BINARY=${DATASTORE_SERVER_BINARY:="${DATASTORE_BINARY} server"}
export DATASTORE_SERVER_BINARY=${DATASTORE_SERVER_BINARY:="${DATASTORE_BINARY}-server"}
# benchmark
[ -x "${DATASTORE_BINARY}-benchmark" ] && DATASTORE_BENCHMARK_BINARY=${DATASTORE_BENCHMARK_BINARY:="${DATASTORE_BINARY}-benchmark"}
[ -x "${DATASTORE_BINARY}" ] && DATASTORE_BENCHMARK_BINARY=${DATASTORE_BENCHMARK_BINARY:="${DATASTORE_BINARY} benchmark"}
export DATASTORE_BENCHMARK_BINARY="${DATASTORE_BENCHMARK_BINARY:=${DATASTORE_BINARY}-benchmark}"
export DATASTORE_BENCHMARK_OPT="${DATASTORE_BENCHMARK_OPT0:-} ${DATASTORE_BENCHMARK_OPT:-}"
export DATASTORE_BENCHMARK=${DATASTORE_BENCHMARK:="$DATASTORE_BENCHMARK_BINARY ${DATASTORE_BENCHMARK_OPT:-}"}
# obfuscator
[ -x "${DATASTORE_BINARY}-obfuscator" ] && DATASTORE_OBFUSCATOR=${DATASTORE_OBFUSCATOR:="${DATASTORE_BINARY}-obfuscator"}
[ -x "${DATASTORE_BINARY}" ] && DATASTORE_OBFUSCATOR=${DATASTORE_OBFUSCATOR:="${DATASTORE_BINARY} obfuscator"}
export DATASTORE_OBFUSCATOR=${DATASTORE_OBFUSCATOR:="${DATASTORE_BINARY}-obfuscator"}
# compressor
[ -x "${DATASTORE_BINARY}-compressor" ] && DATASTORE_COMPRESSOR=${DATASTORE_COMPRESSOR:="${DATASTORE_BINARY}-compressor"}
[ -x "${DATASTORE_BINARY}" ] && DATASTORE_COMPRESSOR=${DATASTORE_COMPRESSOR:="${DATASTORE_BINARY} compressor"}
export DATASTORE_COMPRESSOR=${DATASTORE_COMPRESSOR:="${DATASTORE_BINARY}-compressor"}


export DATASTORE_CONFIG_DIR=${DATASTORE_CONFIG_DIR:="/etc/datastore-server"}
export DATASTORE_CONFIG=${DATASTORE_CONFIG:="/etc/datastore-server/config.xml"}
export DATASTORE_CONFIG_CLIENT=${DATASTORE_CONFIG_CLIENT:="/etc/datastore-client/config.xml"}

export DATASTORE_USER_FILES=${DATASTORE_USER_FILES:="/var/lib/datastore/user_files"}
export DATASTORE_USER_FILES_UNIQUE=${DATASTORE_USER_FILES_UNIQUE:="${DATASTORE_USER_FILES}/${DATASTORE_TEST_UNIQUE_NAME}"}
# synonym
export USER_FILES_PATH=$DATASTORE_USER_FILES

export DATASTORE_SCHEMA_FILES=${DATASTORE_SCHEMA_FILES:="/var/lib/datastore/format_schemas"}
export DATASTORE_DISKS_FILES=${DATASTORE_DISKS_FILES:="/var/lib/datastore/disks"}

[ -x "${DATASTORE_BINARY}-extract-from-config" ] && DATASTORE_EXTRACT_CONFIG=${DATASTORE_EXTRACT_CONFIG:="$DATASTORE_BINARY-extract-from-config --config=$DATASTORE_CONFIG"}
[ -x "${DATASTORE_BINARY}" ] && DATASTORE_EXTRACT_CONFIG=${DATASTORE_EXTRACT_CONFIG:="$DATASTORE_BINARY extract-from-config --config=$DATASTORE_CONFIG"}
export DATASTORE_EXTRACT_CONFIG=${DATASTORE_EXTRACT_CONFIG:="$DATASTORE_BINARY-extract-from-config --config=$DATASTORE_CONFIG"}

[ -x "${DATASTORE_BINARY}-format" ] && DATASTORE_FORMAT=${DATASTORE_FORMAT:="$DATASTORE_BINARY-format"}
[ -x "${DATASTORE_BINARY}" ] && DATASTORE_FORMAT=${DATASTORE_FORMAT:="$DATASTORE_BINARY format"}
export DATASTORE_FORMAT=${DATASTORE_FORMAT:="$DATASTORE_BINARY-format"}

export DATASTORE_CONFIG_GREP=${DATASTORE_CONFIG_GREP:="/etc/datastore-server/preprocessed/config.xml"}

export DATASTORE_HOST=${DATASTORE_HOST:="localhost"}
export DATASTORE_PORT_TCP=${DATASTORE_PORT_TCP:=$(${DATASTORE_EXTRACT_CONFIG} --try --key=tcp_port 2>/dev/null)} 2>/dev/null
export DATASTORE_PORT_TCP=${DATASTORE_PORT_TCP:="9000"}
export DATASTORE_PORT_TCP_SECURE=${DATASTORE_PORT_TCP_SECURE:=$(${DATASTORE_EXTRACT_CONFIG} --try --key=tcp_port_secure 2>/dev/null)} 2>/dev/null
export DATASTORE_PORT_TCP_SECURE=${DATASTORE_PORT_TCP_SECURE:="9440"}
export DATASTORE_PORT_TCP_WITH_PROXY=${DATASTORE_PORT_TCP_WITH_PROXY:=$(${DATASTORE_EXTRACT_CONFIG} --try --key=tcp_with_proxy_port 2>/dev/null)} 2>/dev/null
export DATASTORE_PORT_TCP_WITH_PROXY=${DATASTORE_PORT_TCP_WITH_PROXY:="9010"}
export DATASTORE_PORT_HTTP=${DATASTORE_PORT_HTTP:=$(${DATASTORE_EXTRACT_CONFIG} --key=http_port 2>/dev/null)}
export DATASTORE_PORT_HTTP=${DATASTORE_PORT_HTTP:="8123"}
export DATASTORE_PORT_PROMTHEUS_PORT=${DATASTORE_PORT_PROMTHEUS_PORT:=$(${DATASTORE_EXTRACT_CONFIG} --key=prometheus.port 2>/dev/null)}
export DATASTORE_PORT_PROMTHEUS_PORT=${DATASTORE_PORT_PROMTHEUS_PORT:="9988"}
export DATASTORE_PORT_HTTPS=${DATASTORE_PORT_HTTPS:=$(${DATASTORE_EXTRACT_CONFIG} --try --key=https_port 2>/dev/null)} 2>/dev/null
export DATASTORE_PORT_HTTPS=${DATASTORE_PORT_HTTPS:="8443"}
export DATASTORE_PORT_HTTP_PROTO=${DATASTORE_PORT_HTTP_PROTO:="http"}
export DATASTORE_PORT_MYSQL=${DATASTORE_PORT_MYSQL:=$(${DATASTORE_EXTRACT_CONFIG} --try --key=mysql_port 2>/dev/null)} 2>/dev/null
export DATASTORE_PORT_MYSQL=${DATASTORE_PORT_MYSQL:="9004"}
export DATASTORE_PORT_POSTGRESQL=${DATASTORE_PORT_POSTGRESQL:=$(${DATASTORE_EXTRACT_CONFIG} --try --key=postgresql_port 2>/dev/null)} 2>/dev/null
export DATASTORE_PORT_POSTGRESQL=${DATASTORE_PORT_POSTGRESQL:="9005"}
export DATASTORE_PORT_KEEPER=${DATASTORE_PORT_KEEPER:=$(${DATASTORE_EXTRACT_CONFIG} --try --key=keeper_server.tcp_port 2>/dev/null)} 2>/dev/null
export DATASTORE_PORT_KEEPER=${DATASTORE_PORT_KEEPER:="9181"}
export DATASTORE_PORT_SSH=${DATASTORE_PORT_SSH:=$(${DATASTORE_EXTRACT_CONFIG} --try --key=tcp_ssh_port 2>/dev/null)} 2>/dev/null
export DATASTORE_PORT_SSH=${DATASTORE_PORT_SSH:="9022"}

export DATASTORE_KEEPER_IDENTITY=${DATASTORE_KEEPER_IDENTITY:=$(${DATASTORE_EXTRACT_CONFIG} --try --key=zookeeper.identity 2>/dev/null)} 2>/dev/null
export DATASTORE_KEEPER_IDENTITY=${DATASTORE_KEEPER_IDENTITY:=""}

# keeper-client

KEEPER_CLIENT_DEFAULT_ARGS=" --port $DATASTORE_PORT_KEEPER"

if [ -n "$DATASTORE_KEEPER_IDENTITY" ] && [ "$DATASTORE_KEEPER_IDENTITY" != "" ]
then
    KEEPER_CLIENT_DEFAULT_ARGS="$KEEPER_CLIENT_DEFAULT_ARGS --identity $DATASTORE_KEEPER_IDENTITY"
fi

[ -x "${DATASTORE_BINARY}-keeper-client" ] && DATASTORE_KEEPER_CLIENT=${DATASTORE_KEEPER_CLIENT:="${DATASTORE_BINARY}-keeper-client $KEEPER_CLIENT_DEFAULT_ARGS"}
[ -x "${DATASTORE_BINARY}" ] && DATASTORE_KEEPER_CLIENT=${DATASTORE_KEEPER_CLIENT:="${DATASTORE_BINARY} keeper-client $KEEPER_CLIENT_DEFAULT_ARGS"}
export DATASTORE_KEEPER_CLIENT=${DATASTORE_KEEPER_CLIENT:="${DATASTORE_BINARY}-keeper-client $KEEPER_CLIENT_DEFAULT_ARGS"}

export DATASTORE_CLIENT_SECURE=${DATASTORE_CLIENT_SECURE:=$(echo "${DATASTORE_CLIENT}" | sed 's/--secure //' | sed 's/'"--port=${DATASTORE_PORT_TCP}"'//g; s/$/'"--secure --accept-invalid-certificate --port=${DATASTORE_PORT_TCP_SECURE}"'/g')}

# Add database and log comment to url params
if [ -n "${DATASTORE_URL_PARAMS:-}" ]
then
  export DATASTORE_URL_PARAMS="${DATASTORE_URL_PARAMS}&database=${DATASTORE_DATABASE}"
else
  export DATASTORE_URL_PARAMS="database=${DATASTORE_DATABASE}"
fi
# Note: missing url encoding of the log comment.
[ -n "${DATASTORE_LOG_COMMENT:-}" ] && export DATASTORE_URL_PARAMS="${DATASTORE_URL_PARAMS}&log_comment=${DATASTORE_LOG_COMMENT}"

export DATASTORE_URL=${DATASTORE_URL:="${DATASTORE_PORT_HTTP_PROTO}://${DATASTORE_HOST}:${DATASTORE_PORT_HTTP}/"}
export DATASTORE_URL_HTTPS=${DATASTORE_URL_HTTPS:="https://${DATASTORE_HOST}:${DATASTORE_PORT_HTTPS}/"}
export DATASTORE_URL="${DATASTORE_URL}?${DATASTORE_URL_PARAMS}"
export DATASTORE_URL_HTTPS="${DATASTORE_URL_HTTPS}?${DATASTORE_URL_PARAMS}"

export DATASTORE_URL_PROMETHEUS=${DATASTORE_URL_PROMETHEUS:="${DATASTORE_PORT_HTTP_PROTO}://${DATASTORE_HOST}:${DATASTORE_PORT_PROMTHEUS_PORT}/metrics"}

export DATASTORE_PORT_INTERSERVER=${DATASTORE_PORT_INTERSERVER:=$(${DATASTORE_EXTRACT_CONFIG} --try --key=interserver_http_port 2>/dev/null)} 2>/dev/null
export DATASTORE_PORT_INTERSERVER=${DATASTORE_PORT_INTERSERVER:="9009"}
export DATASTORE_URL_INTERSERVER=${DATASTORE_URL_INTERSERVER:="${DATASTORE_PORT_HTTP_PROTO}://${DATASTORE_HOST}:${DATASTORE_PORT_INTERSERVER}/"}

export DATASTORE_CURL_COMMAND=${DATASTORE_CURL_COMMAND:="curl"}
# The queries in CI are prone to sudden delays, and we often don't check for curl
# errors, so it makes sense to set a relatively generous timeout.
export DATASTORE_CURL_TIMEOUT=${DATASTORE_CURL_TIMEOUT:="120"}
export DATASTORE_CURL=${DATASTORE_CURL:="${DATASTORE_CURL_COMMAND} -q -s --max-time ${DATASTORE_CURL_TIMEOUT}"}
export DATASTORE_TMP=${DATASTORE_TMP:="."}
mkdir -p ${DATASTORE_TMP}

export MYSQL_CLIENT_BINARY=${MYSQL_CLIENT_BINARY:="mysql"}
export MYSQL_CLIENT_DATASTORE_USER=${MYSQL_CLIENT_DATASTORE_USER:="default"}
# Avoids "Can't connect to local MySQL server through socket '/var/run/mysqld/mysqld.sock'" when connecting to localhost
[ -n "${DATASTORE_HOST:-}" ] && MYSQL_CLIENT_OPT0+=" --protocol tcp "
[ -n "${DATASTORE_HOST:-}" ] && MYSQL_CLIENT_OPT0+=" --host ${DATASTORE_HOST} "
[ -n "${DATASTORE_PORT_MYSQL:-}" ] && MYSQL_CLIENT_OPT0+=" --port ${DATASTORE_PORT_MYSQL} "
[ -n "${DATASTORE_DATABASE:-}" ] && MYSQL_CLIENT_OPT0+=" --database ${DATASTORE_DATABASE} "
MYSQL_CLIENT_OPT0+=" --user ${MYSQL_CLIENT_DATASTORE_USER} --no-auto-rehash "
export MYSQL_CLIENT_OPT="${MYSQL_CLIENT_OPT0:-} ${MYSQL_CLIENT_OPT:-}"
export MYSQL_CLIENT=${MYSQL_CLIENT:="$MYSQL_CLIENT_BINARY ${MYSQL_CLIENT_OPT:-}"}

export PROTOC_BINARY=${PROTOC_BINARY:="protoc"}

function clickhouse_client_removed_host_parameter()
{
    # removing only `--host=value` and `--host value` (removing '-hvalue' feels to dangerous) with python regex.
    # bash regex magic is arcane, but version dependant and weak; sed or awk are not really portable.
    $(echo "$DATASTORE_CLIENT"  | python3 -c "import sys, re; print(re.sub(r'--host(\s+|=)[^\s]+', '', sys.stdin.read()))") "$@"
}

function wait_for_query_to_start()
{
    local query_id="$1"
    local timeout="${2:-120}"
    local start=$EPOCHSECONDS
    while [[ $($DATASTORE_CURL -sS "$DATASTORE_URL" -d "SELECT count() FROM system.processes WHERE query_id = '$query_id' SETTINGS use_query_cache = 0") == 0 ]]; do
        if ((EPOCHSECONDS - start > timeout)); then
            echo "Timeout waiting for query $query_id to start" >&2
            exit 1
        fi
        sleep 0.1
    done
}

function wait_for_queries_to_finish()
{
    local max_tries="${1:-20}"
    # Wait for all queries to finish (query may still be running if a thread is killed by timeout)
    local num_tries=0
    while [[ $($DATASTORE_CLIENT -q "SELECT count() FROM system.processes WHERE current_database=currentDatabase() AND query NOT LIKE '%system.processes%'") -ne 0 ]]; do
        sleep 0.5;
        num_tries=$((num_tries+1))
        if [ $num_tries -eq $max_tries ]; then
            $DATASTORE_CLIENT -q "SELECT * FROM system.processes WHERE current_database=currentDatabase() AND query NOT LIKE '%system.processes%' FORMAT Vertical"
            break
        fi
    done
}

function random_str()
{
    local n=$1 && shift
    tr -cd '[:lower:]' < /dev/urandom | head -c"$n"
}

function query_with_retry()
{
    local query="$1" && shift

    local retry=0
    until [ $retry -ge 5 ]
    do
        local result
        result="$($DATASTORE_CLIENT "$@" --query="$query" 2>&1)"
        if [ "$?" == 0 ]; then
            echo -n "$result"
            return
        else
            retry=$((retry + 1))
            sleep 3
        fi
    done
    echo "Query '$query' failed with '$result'"
}

function run_with_error()
{
    local cmd="$1"; shift

    local stdout_tmp=""
    stdout_tmp=$(mktemp -p ${DATASTORE_TMP})
    local stderr_tmp=""
    stderr_tmp=$(mktemp -p ${DATASTORE_TMP})

    local retval=0
    $cmd "$@" 1>${stdout_tmp} 2>${stderr_tmp} || retval="$?"

    echo "${retval}" "${stdout_tmp}" "${stderr_tmp}"

    return 0
}

function with_lock()
{
    local lock_file="${DATASTORE_TMP}/lock_${DATASTORE_TEST_UNIQUE_NAME}_$1.lock"; shift
    flock "$lock_file" "$@"
}

# BASH_XTRACEFD is supported only since 4.1
if [[ -n "${DATASTORE_BASH_TRACING_FILE+x}" ]] && [[ ${BASH_VERSINFO[0]} -gt 4 || (${BASH_VERSINFO[0]} -eq 4 && ${BASH_VERSINFO[1]} -ge 1) ]]; then
    exec 3>"$DATASTORE_BASH_TRACING_FILE"
    # It will be also nice to have stderr in the tracing output, but:
    # - exec 2>&3
    #
    #   This will not preserve it in the stderr, and even though explicit
    #   stderr handling in tests will work, the check for non-empty stderr will
    #   not work at least
    #
    # - exec 2> >(stdbuf -o0 -e0 -i0 tee -a "$DATASTORE_BASH_TRACING_FILE" >&2)
    #
    #   The problem with duplicating stderr with tee is bufferization, even
    #   with "tee -a" (opens with O_APPEND) and stdbuf I still got stderr after tracing
    #
    #   I've also tried unbuffer but it does not work
    #
    # But anyway it is useful even without stderr!
    #
    # Note, that we can redirect stderr into separate file, this should work,
    # but we will have to add a code to handle this in datastore-test wrapper,
    # but let's keep things simple for now.
    BASH_XTRACEFD=3
    export PS4='+ [\D{%Y-%m-%d %H:%M:%S}] [:${LINENO}] '
    set -x
fi
