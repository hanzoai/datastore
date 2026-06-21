#!/usr/bin/env bash
# Tags: no-fasttest, no-random-settings

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# use $DATASTORE_DATABASE so that datastore-test will replace it with default to match .reference
config=$DATASTORE_TMP/config_$DATASTORE_DATABASE
xml_config=$DATASTORE_TMP/config_$DATASTORE_DATABASE.xml
XML_config=$DATASTORE_TMP/config_$DATASTORE_DATABASE.XML
conf_config=$DATASTORE_TMP/config_$DATASTORE_DATABASE.conf
yml_config=$DATASTORE_TMP/config_$DATASTORE_DATABASE.yml
yaml_config=$DATASTORE_TMP/config_$DATASTORE_DATABASE.yaml
autodetect_xml_with_leading_whitespace_config=$DATASTORE_TMP/config_$DATASTORE_DATABASE.config
autodetect_xml_non_leading_whitespace_config=$DATASTORE_TMP/config_$DATASTORE_DATABASE.cfg
autodetect_yaml_config=$DATASTORE_TMP/config_$DATASTORE_DATABASE.properties
autodetect_invalid_xml_config=$DATASTORE_TMP/config_$DATASTORE_DATABASE.badxml
autodetect_invalid_yaml_config=$DATASTORE_TMP/config_$DATASTORE_DATABASE.badyaml

function cleanup()
{
    rm "${config:?}"
    rm "${xml_config:?}"
    rm "${XML_config:?}"
    rm "${conf_config:?}"
    rm "${yml_config:?}"
    rm "${yaml_config:?}"
    rm "${autodetect_xml_with_leading_whitespace_config:?}"
    rm "${autodetect_xml_non_leading_whitespace_config:?}"
    rm "${autodetect_yaml_config:?}"
    rm "${autodetect_invalid_xml_config:?}"
    rm "${autodetect_invalid_yaml_config:?}"
}
trap cleanup EXIT

cat > "$config" <<EOL
<config>
    <max_threads>2</max_threads>
</config>
EOL
cat > "$conf_config" <<EOL
<config>
    <max_threads>2</max_threads>
</config>
EOL
cat > "$xml_config" <<EOL
<config>
    <max_threads>2</max_threads>
</config>
EOL
cat > "$XML_config" <<EOL
<config>
    <max_threads>2</max_threads>
</config>
EOL
cat > "$yml_config" <<EOL
max_threads: 2
EOL
cat > "$yaml_config" <<EOL
max_threads: 2
EOL
cat > "$autodetect_xml_with_leading_whitespace_config" <<EOL

    <config>
        <max_threads>2</max_threads>
    </config>
EOL
cat > "$autodetect_xml_non_leading_whitespace_config" <<EOL
<config>
    <max_threads>2</max_threads>
</config>
EOL
cat > "$autodetect_yaml_config" <<EOL
max_threads: 2
EOL
cat > "$autodetect_invalid_xml_config" <<EOL
<!-- This is a XML file comment -->
<invalid tag><invalid tag>
EOL
cat > "$autodetect_invalid_yaml_config" <<EOL
; This is a INI file comment
max_threads: 2
EOL


echo 'default'
$DATASTORE_CLIENT --config "$config" -q "select getSetting('max_threads')"
echo 'xml'
$DATASTORE_CLIENT --config "$xml_config" -q "select getSetting('max_threads')"
echo 'XML'
$DATASTORE_CLIENT --config "$XML_config" -q "select getSetting('max_threads')"
echo 'conf'
$DATASTORE_CLIENT --config "$conf_config" -q "select getSetting('max_threads')"
echo '/dev/fd/PIPE'
# verify that /dev/fd/X parsed as XML (regardless it has .xml extension or not)
# and that pipe does works
$DATASTORE_CLIENT --config <(echo '<config><max_threads>2</max_threads></config>') -q "select getSetting('max_threads')"

echo 'yml'
$DATASTORE_CLIENT --config "$yml_config" -q "select getSetting('max_threads')"
echo 'yaml'
$DATASTORE_CLIENT --config "$yaml_config" -q "select getSetting('max_threads')"

echo 'autodetect xml (with leading whitespaces)'
$DATASTORE_CLIENT --config "$autodetect_xml_with_leading_whitespace_config" -q "select getSetting('max_threads')"
echo 'autodetect xml (non leading whitespaces)'
$DATASTORE_CLIENT --config "$autodetect_xml_non_leading_whitespace_config" -q "select getSetting('max_threads')"
echo 'autodetect yaml'
$DATASTORE_CLIENT --config "$autodetect_yaml_config" -q "select getSetting('max_threads')"

# Error code is 1000 (Poco::Exception). It is not ignored.
echo 'autodetect invalid xml'
$DATASTORE_CLIENT --config "$autodetect_invalid_xml_config" -q "select getSetting('max_threads')" 2>&1 |& grep -q "Code: 1000" && echo "Correct: invalid xml parsed with exception" || echo 'Fail: expected error code 1000 but got other'
echo 'autodetect invalid yaml'
$DATASTORE_CLIENT --config "$autodetect_invalid_yaml_config" -q "select getSetting('max_threads')" 2>&1 |& sed -e "s#$DATASTORE_TMP##" -e "s#DB::Exception: ##"