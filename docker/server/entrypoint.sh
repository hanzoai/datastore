#!/bin/bash

set -eo pipefail
shopt -s nullglob

DO_CHOWN=1
if [[ "${HANZO_RUN_AS_ROOT:=0}" = "1" || "${HANZO_DO_NOT_CHOWN:-0}" = "1" ]]; then
    DO_CHOWN=0
fi

# support `docker run --user=xxx:xxxx`
if [[ "$(id -u)" = "0" ]]; then
    if [[ "$HANZO_RUN_AS_ROOT" = 1 ]]; then
        USER=0
        GROUP=0
    else
        USER="${HANZO_UID:-"$(id -u hanzo-datastore)"}"
        GROUP="${HANZO_GID:-"$(id -g hanzo-datastore)"}"
    fi
else
    USER="$(id -u)"
    GROUP="$(id -g)"
    DO_CHOWN=0
fi

# set some vars
HANZO_CONFIG="${HANZO_CONFIG:-/etc/hanzo-datastore-server/config.xml}"

# get directories locations
DATA_DIR="$(hanzo-datastore extract-from-config --config-file "$HANZO_CONFIG" --key=path || true)"
TMP_DIR="$(hanzo-datastore extract-from-config --config-file "$HANZO_CONFIG" --key=tmp_path || true)"
USER_PATH="$(hanzo-datastore extract-from-config --config-file "$HANZO_CONFIG" --key=user_files_path || true)"
LOG_PATH="$(hanzo-datastore extract-from-config --config-file "$HANZO_CONFIG" --key=logger.log || true)"
LOG_DIR=""
if [ -n "$LOG_PATH" ]; then LOG_DIR="$(dirname "$LOG_PATH")"; fi
ERROR_LOG_PATH="$(hanzo-datastore extract-from-config --config-file "$HANZO_CONFIG" --key=logger.errorlog || true)"
ERROR_LOG_DIR=""
if [ -n "$ERROR_LOG_PATH" ]; then ERROR_LOG_DIR="$(dirname "$ERROR_LOG_PATH")"; fi
FORMAT_SCHEMA_PATH="$(hanzo-datastore extract-from-config --config-file "$HANZO_CONFIG" --key=format_schema_path || true)"

# There could be many disks declared in config
readarray -t DISKS_PATHS < <(hanzo-datastore extract-from-config --config-file "$HANZO_CONFIG" --key='storage_configuration.disks.*.path' || true)
readarray -t DISKS_METADATA_PATHS < <(hanzo-datastore extract-from-config --config-file "$HANZO_CONFIG" --key='storage_configuration.disks.*.metadata_path' || true)

HANZO_USER="${HANZO_USER:-default}"
HANZO_PASSWORD_FILE="${HANZO_PASSWORD_FILE:-}"
if [[ -n "${HANZO_PASSWORD_FILE}" && -f "${HANZO_PASSWORD_FILE}" ]]; then
    HANZO_PASSWORD="$(cat "${HANZO_PASSWORD_FILE}")"
fi
HANZO_PASSWORD="${HANZO_PASSWORD:-}"
HANZO_DB="${HANZO_DB:-}"
HANZO_ACCESS_MANAGEMENT="${HANZO_DEFAULT_ACCESS_MANAGEMENT:-0}"
HANZO_SKIP_USER_SETUP="${HANZO_SKIP_USER_SETUP:-0}"

function create_directory_and_do_chown() {
    local dir=$1
    # check if variable not empty
    [ -z "$dir" ] && return
    # ensure directories exist
    if [ "$DO_CHOWN" = "1" ]; then
        mkdir=( mkdir )
    else
        # if DO_CHOWN=0 it means that the system does not map root user to "admin" permissions
        # it mainly happens on NFS mounts where root==nobody for security reasons
        # thus mkdir MUST run with user id/gid and not from nobody that has zero permissions
        mkdir=( hanzo-datastore su "${USER}:${GROUP}" mkdir )
    fi
    if ! "${mkdir[@]}" -p "$dir"; then
        echo "Couldn't create necessary directory: $dir"
        exit 1
    fi

    if [ "$DO_CHOWN" = "1" ]; then
        # ensure proper directories permissions
        # but skip it for if directory already has proper premissions, cause recursive chown may be slow
        if [ "$(stat -c %u "$dir")" != "$USER" ] || [ "$(stat -c %g "$dir")" != "$GROUP" ]; then
            chown -R "$USER:$GROUP" "$dir"
        fi
    fi
}

function manage_directories() {
    for dir in "$ERROR_LOG_DIR" \
      "$LOG_DIR" \
      "$TMP_DIR" \
      "$USER_PATH" \
      "$FORMAT_SCHEMA_PATH" \
      "${DISKS_PATHS[@]}" \
      "${DISKS_METADATA_PATHS[@]}"
    do
        create_directory_and_do_chown "$dir"
    done
}

function manage_user() {
    # Check if the `default` user is changed through any mounted file. It will mean that user took care of it already
    # First, extract the users_xml.path and check it's relative or absolute
    local USERS_XML USERS_CONFIG
    USERS_XML=$(hanzo-datastore extract-from-config --config-file "$HANZO_CONFIG" --key='user_directories.users_xml.path')
    case $USERS_XML in
        /* ) # absolute path
            cp "$USERS_XML" /tmp
            USERS_CONFIG="/tmp/$(basename $USERS_XML)"
            ;;
        * ) # relative path to the $HANZO_CONFIG
            cp "$(dirname "$HANZO_CONFIG")/${USERS_XML}" /tmp
            USERS_CONFIG="/tmp/$(basename $USERS_XML)"
            ;;
    esac

    # Compare original `users.default` to the processed one
    local ORIGINAL_DEFAULT PROCESSED_DEFAULT HANZO_DEFAULT_CHANGED
    ORIGINAL_DEFAULT=$(hanzo-datastore extract-from-config --config-file "$USERS_CONFIG" --key='users.default' | sha256sum)
    PROCESSED_DEFAULT=$(hanzo-datastore extract-from-config --config-file "$HANZO_CONFIG" --users --key='users.default' --try | sha256sum)
    [ "$ORIGINAL_DEFAULT" == "$PROCESSED_DEFAULT" ] && HANZO_DEFAULT_CHANGED=0 || HANZO_DEFAULT_CHANGED=1

    if [ "$HANZO_SKIP_USER_SETUP" == "1" ]; then
        echo "$0: explicitly skip changing user 'default'"
    elif [ -n "$HANZO_USER" ] && [ "$HANZO_USER" != "default" ] || [ -n "$HANZO_PASSWORD" ] || [ "$HANZO_ACCESS_MANAGEMENT" != "0" ]; then
        # if hanzo user is defined - create it (user "default" already exists out of box)
        echo "$0: create new user '$HANZO_USER' instead 'default'"
        cat <<EOT > /etc/hanzo-datastore-server/users.d/default-user.xml
<hanzo-datastore>
  <!-- Docs: <https://hanzo.ai/docs/operations/settings/settings_users/> -->
  <users>
    <!-- Remove default user -->
    <default remove="remove">
    </default>

    <${HANZO_USER}>
      <profile>default</profile>
      <networks>
        <ip>::/0</ip>
      </networks>
      <password><![CDATA[${HANZO_PASSWORD//]]>/]]]]><![CDATA[>}]]></password>
      <quota>default</quota>
      <access_management>${HANZO_ACCESS_MANAGEMENT}</access_management>
    </${HANZO_USER}>
  </users>
</hanzo-datastore>
EOT
    elif [ "$HANZO_DEFAULT_CHANGED" == "1" ]; then
        # Leave users as is, do nothing
        :
    else
        echo "$0: neither HANZO_USER nor HANZO_PASSWORD is set, disabling network access for user '$HANZO_USER'"
        cat <<EOT > /etc/hanzo-datastore-server/users.d/default-user.xml
<hanzo-datastore>
  <!-- Docs: <https://hanzo.ai/docs/operations/settings/settings_users/> -->
  <users>
    <default>
      <!-- User default is available only locally -->
      <networks>
        <ip>::1</ip>
        <ip>127.0.0.1</ip>
      </networks>
    </default>
  </users>
</hanzo-datastore>
EOT
    fi
}

HANZO_ALWAYS_RUN_INITDB_SCRIPTS="${HANZO_ALWAYS_RUN_INITDB_SCRIPTS:-}"

function init_db() {
    # checking $DATA_DIR for initialization
    if [ -d "${DATA_DIR%/}/data" ]; then
        DATABASE_ALREADY_EXISTS='true'
    fi

    # run initialization if flag HANZO_ALWAYS_RUN_INITDB_SCRIPTS is not empty or data directory is empty
    if [[ -n "${HANZO_ALWAYS_RUN_INITDB_SCRIPTS}" || -z "${DATABASE_ALREADY_EXISTS}" ]]; then
      RUN_INITDB_SCRIPTS='true'
    fi

    if [ -n "${RUN_INITDB_SCRIPTS}" ]; then
        if [ -n "$(ls /docker-entrypoint-initdb.d/)" ] || [ -n "$HANZO_DB" ]; then
            # port is needed to check if server is ready for connections
            HTTP_PORT="$(hanzo-datastore extract-from-config --config-file "$HANZO_CONFIG" --key=http_port --try)"
            HTTPS_PORT="$(hanzo-datastore extract-from-config --config-file "$HANZO_CONFIG" --key=https_port --try)"
            NATIVE_PORT="$(hanzo-datastore extract-from-config --config-file "$HANZO_CONFIG" --key=tcp_port --try)"

            if [ -n "$HTTP_PORT" ]; then
                URL="http://127.0.0.1:$HTTP_PORT/ping"
            else
                URL="https://127.0.0.1:$HTTPS_PORT/ping"
            fi

            # Listen only on localhost until the initialization is done
            hanzo-datastore su "${USER}:${GROUP}" hanzo-datastore-server --config-file="$HANZO_CONFIG" -- --listen_host=127.0.0.1 &
            pid="$!"

            # check if server is ready to accept connections
            # will try to send ping via http_port (max 1000 retries by default, with 1 sec timeout and 1 sec delay between retries)
            tries=${HANZO_INIT_TIMEOUT:-1000}
            while ! wget --spider --no-check-certificate -T 1 -q "$URL" 2>/dev/null; do
                if [ "$tries" -le "0" ]; then
                    echo >&2 'Hanzo Datastore init process timeout.'
                    exit 1
                fi
                tries=$(( tries-1 ))
                sleep 1
            done

            hanzoclient=( hanzo-datastore-client --multiquery --host "127.0.0.1" --port "$NATIVE_PORT" -u "$HANZO_USER" --password "$HANZO_PASSWORD" )

            echo

            # create default database, if defined
            if [ -n "$HANZO_DB" ]; then
                echo "$0: create database '$HANZO_DB'"
                "${hanzoclient[@]}" -q "CREATE DATABASE IF NOT EXISTS $HANZO_DB";
            fi

            for f in /docker-entrypoint-initdb.d/*; do
                case "$f" in
                    *.sh)
                        if [ -x "$f" ]; then
                            echo "$0: running $f"
                            "$f"
                        else
                            echo "$0: sourcing $f"
                            # shellcheck source=/dev/null
                            . "$f"
                        fi
                        ;;
                    *.sql)    echo "$0: running $f"; "${hanzoclient[@]}" < "$f" ; echo ;;
                    *.sql.gz) echo "$0: running $f"; gunzip -c "$f" | "${hanzoclient[@]}"; echo ;;
                    *)        echo "$0: ignoring $f" ;;
                esac
                echo
            done

            if ! kill -s TERM "$pid" || ! wait "$pid"; then
                echo >&2 'Finishing of Hanzo Datastore init process failed.'
                exit 1
            fi
        fi
    else
        echo "Hanzo Datastore directory appears to contain a database; Skipping initialization"
    fi
}

# if no args passed to `docker run` or first argument start with `--`, then the user is passing server arguments
if [[ $# -lt 1 ]] || [[ "$1" == "--"* ]]; then
    # Watchdog is launched by default, but does not send SIGINT to the main process,
    # so the container can't be finished by ctrl+c
    HANZO_WATCHDOG_ENABLE=${HANZO_WATCHDOG_ENABLE:-0}
    export HANZO_WATCHDOG_ENABLE

    create_directory_and_do_chown "$DATA_DIR"

    # Change working directory to $DATA_DIR in case there're paths relative to $DATA_DIR, also avoids running
    # server at root directory.
    cd "$DATA_DIR"

    # Using functions here to avoid unnecessary work in case of launching other binaries,
    # inspired by postgres, mariadb etc. entrypoints
    # It is necessary to pass the docker library consistency test
    manage_directories
    manage_user
    init_db

    # This replaces the shell script with the server:
    exec hanzo-datastore su "${USER}:${GROUP}" hanzo-datastore-server --config-file="$HANZO_CONFIG" "$@"
fi

# Otherwise, we assume the user want to run his own process, for example a `bash` shell to explore this image
exec "$@"

# vi: ts=4: sw=4: sts=4: expandtab
