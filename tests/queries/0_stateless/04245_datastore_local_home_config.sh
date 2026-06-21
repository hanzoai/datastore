#!/usr/bin/env bash
# Regression for https://github.com/ClickHouse/Datastore/issues/104932

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

TESTDIR="${USER_FILES_PATH}/${DATASTORE_DATABASE}_104932"
trap 'rm -rf "$TESTDIR"' EXIT

rm -rf "$TESTDIR"
mkdir -p "$TESTDIR/home/.datastore-local"
mkdir -p "$TESTDIR/cwd"

cat > "$TESTDIR/home/.datastore-local/config.xml" <<EOF
<datastore>
    <user_directories>
        <users_xml>
            <path>users.xml</path>
        </users_xml>
    </user_directories>
</datastore>
EOF
cat > "$TESTDIR/home/.datastore-local/users.xml" <<EOF
<datastore>
    <profiles>
        <default>
            <max_threads>42</max_threads>
        </default>
    </profiles>
    <users>
        <default>
            <password></password>
            <networks><ip>::/0</ip></networks>
            <profile>default</profile>
            <quota>default</quota>
        </default>
    </users>
    <quotas>
        <default></default>
    </quotas>
</datastore>
EOF

echo "-- HOME/.datastore-local/config.xml"
(
    cd "$TESTDIR/cwd" || exit 1
    HOME="$TESTDIR/home" "$DATASTORE_LOCAL" --query "SELECT getSetting('max_threads')"
)

echo "-- ./datastore-local.xml"
(
    cd "$TESTDIR/cwd" || exit 1
    cp "$TESTDIR/home/.datastore-local/config.xml" "./datastore-local.xml"
    cp "$TESTDIR/home/.datastore-local/users.xml" "./users.xml"
    HOME="$TESTDIR" "$DATASTORE_LOCAL" --query "SELECT getSetting('max_threads')"
    rm -f "./datastore-local.xml" "./users.xml"
)

echo "-- --config-file"
(
    cd "$TESTDIR/cwd" || exit 1
    HOME="$TESTDIR" "$DATASTORE_LOCAL" \
        --config-file="$TESTDIR/home/.datastore-local/config.xml" \
        --query "SELECT getSetting('max_threads')"
)

echo "-- no config"
mkdir -p "$TESTDIR/empty_home"
(
    cd "$TESTDIR/cwd" || exit 1
    # Default `max_threads` depends on the host's CPU count, so just assert that
    # the query succeeds with a positive integer (i.e. did not crash on missing config).
    OUT=$(HOME="$TESTDIR/empty_home" "$DATASTORE_LOCAL" --query "SELECT getSetting('max_threads') > 0")
    echo "$OUT"
)

# A relative users.xml path next to the loaded config is anchored to the
# config's directory; a missing file fails fast instead of silently picking
# up a `./users.xml` from cwd. Verified for both forms below.
cat > "$TESTDIR/cwd/users.xml" <<EOF
<datastore>
    <profiles>
        <default>
            <max_threads>99</max_threads>
        </default>
    </profiles>
    <users>
        <default>
            <password></password>
            <networks><ip>::/0</ip></networks>
            <profile>default</profile>
            <quota>default</quota>
        </default>
    </users>
    <quotas>
        <default></default>
    </quotas>
</datastore>
EOF

echo "-- missing user_directories.users_xml.path does not silently load cwd users.xml"
mkdir -p "$TESTDIR/orphan_home/.datastore-local"
cat > "$TESTDIR/orphan_home/.datastore-local/config.xml" <<EOF
<datastore>
    <user_directories>
        <users_xml>
            <path>users.xml</path>
        </users_xml>
    </user_directories>
</datastore>
EOF
(
    cd "$TESTDIR/cwd" || exit 1
    HOME="$TESTDIR/orphan_home" "$DATASTORE_LOCAL" --query "SELECT getSetting('max_threads')" 2>&1 \
        | grep -oE 'FILE_DOESNT_EXIST|max_threads' \
        | head -n 1
)

echo "-- missing users_config users.xml does not silently load cwd users.xml"
mkdir -p "$TESTDIR/orphan_home_uc/.datastore-local"
cat > "$TESTDIR/orphan_home_uc/.datastore-local/config.xml" <<EOF
<datastore>
    <users_config>users.xml</users_config>
</datastore>
EOF
(
    cd "$TESTDIR/cwd" || exit 1
    HOME="$TESTDIR/orphan_home_uc" "$DATASTORE_LOCAL" --query "SELECT getSetting('max_threads')" 2>&1 \
        | grep -oE 'FILE_DOESNT_EXIST|max_threads' \
        | head -n 1
)
rm -f "$TESTDIR/cwd/users.xml"
