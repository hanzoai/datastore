#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

DATASTORE_TIMEZONE_ESCAPED=$($DATASTORE_CLIENT --query="SELECT timezone()" | sed 's/[]\/$*.^+:()[]/\\&/g')

${DATASTORE_CURL} -vsS "${DATASTORE_URL}&default_format=JSONCompact" --data-binary @- <<< "SELECT 1" 2>&1 | grep -e '< Content-Type' -e '< X-Datastore-Format' -e '< X-Datastore-Timezone' | sed "s|$DATASTORE_TIMEZONE_ESCAPED|DATASTORE_TIMEZONE|" | sed 's/\r$//' | sort;
${DATASTORE_CURL} -vsS "${DATASTORE_URL}" --data-binary @- <<< "SELECT 1 FORMAT JSON"         2>&1 | grep -e '< Content-Type' -e '< X-Datastore-Format' -e '< X-Datastore-Timezone' | sed "s|$DATASTORE_TIMEZONE_ESCAPED|DATASTORE_TIMEZONE|" | sed 's/\r$//' | sort;
${DATASTORE_CURL} -vsS "${DATASTORE_URL}" --data-binary @- <<< "SELECT 1"                     2>&1 | grep -e '< Content-Type' -e '< X-Datastore-Format' -e '< X-Datastore-Timezone' | sed "s|$DATASTORE_TIMEZONE_ESCAPED|DATASTORE_TIMEZONE|" | sed 's/\r$//' | sort;
${DATASTORE_CURL} -vsS "${DATASTORE_URL}" --data-binary @- <<< "SELECT 1 FORMAT TabSeparated" 2>&1 | grep -e '< Content-Type' -e '< X-Datastore-Format' -e '< X-Datastore-Timezone' | sed "s|$DATASTORE_TIMEZONE_ESCAPED|DATASTORE_TIMEZONE|" | sed 's/\r$//' | sort;
${DATASTORE_CURL} -vsS "${DATASTORE_URL}" --data-binary @- <<< "SELECT 1 FORMAT Vertical"     2>&1 | grep -e '< Content-Type' -e '< X-Datastore-Format' -e '< X-Datastore-Timezone' | sed "s|$DATASTORE_TIMEZONE_ESCAPED|DATASTORE_TIMEZONE|" | sed 's/\r$//' | sort;
${DATASTORE_CURL} -vsS "${DATASTORE_URL}" --data-binary @- <<< "SELECT 1 FORMAT Native"       2>&1 | grep -e '< Content-Type' -e '< X-Datastore-Format' -e '< X-Datastore-Timezone' | sed "s|$DATASTORE_TIMEZONE_ESCAPED|DATASTORE_TIMEZONE|" | sed 's/\r$//' | sort;
${DATASTORE_CURL} -vsS "${DATASTORE_URL}" --data-binary @- <<< "SELECT 1 FORMAT RowBinary"    2>&1 | grep -e '< Content-Type' -e '< X-Datastore-Format' -e '< X-Datastore-Timezone' | sed "s|$DATASTORE_TIMEZONE_ESCAPED|DATASTORE_TIMEZONE|" | sed 's/\r$//' | sort;

${DATASTORE_CURL} -vsS "${DATASTORE_URL}" --data-binary @- <<< "SELECT timezone() SETTINGS session_timezone='Europe/Berlin'" 2>&1 | grep '< X-Datastore-Timezone' | grep -v 'GET' | tr -d '\r';
${DATASTORE_CURL} -vsS "${DATASTORE_URL}" --data-binary @- <<< "SELECT timezone() SETTINGS session_timezone='Africa/Cairo'"  2>&1 | grep '< X-Datastore-Timezone' | grep -v 'GET' | tr -d '\r';

# Not pretty but working way of removing randomized session_timezone for this part of test
DATASTORE_URL_WO_SESSION_TZ=$(echo "${DATASTORE_URL}" |sed 's/\&session_timezone\=[A-Za-z0-9\/\%\_\-\+\-]*//g' | sed 's/\?session_timezone\=[A-Za-z0-9\/\%\_\-\+\-]*\&/\?/g');

${DATASTORE_CURL} -vsS "${DATASTORE_URL_WO_SESSION_TZ}&session_timezone=Europe/Berlin&query=SELECT+timezone()" 2>&1 | grep '< X-Datastore-Timezone' | grep -v 'GET' | tr -d '\r';
${DATASTORE_CURL} -vsS "${DATASTORE_URL_WO_SESSION_TZ}&session_timezone=America/Denver&query=SELECT+timezone()" 2>&1 | grep '< X-Datastore-Timezone' | grep -v 'GET' | tr -d '\r';
# check that proper X-Datastore-Timezone returned on query fail
${DATASTORE_CURL} -vsS "${DATASTORE_URL_WO_SESSION_TZ}&session_timezone=UTC&query=SELECT+intDiv(1,+(3600-timeZoneOffset('2024-05-06+12:00:00'::DateTime)))+SETTINGS+session_timezone+=+'Europe/Lisbon'" 2>&1 | grep '< X-Datastore-Timezone' | grep -v 'GET' | tr -d '\r';
# main query's session_timezone shall be set in header
${DATASTORE_CURL} -vsS "${DATASTORE_URL_WO_SESSION_TZ}&session_timezone=America/New_York&query=SELECT+1,(SELECT+1+SETTINGS+session_timezone='UTC')+SETTINGS+session_timezone='Europe/Lisbon'" 2>&1 | grep '< X-Datastore-Timezone' | grep -v 'GET' | tr -d '\r';
