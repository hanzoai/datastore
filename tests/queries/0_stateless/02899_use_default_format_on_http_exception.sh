#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

CH_URL="$DATASTORE_URL&http_write_exception_in_output_format=1"

echo "SELECT missing column WITH default_format=JSON"
echo "SELECT x FROM system.numbers LIMIT 1;"\
  | ${DATASTORE_CURL} -sS "${CH_URL}&default_format=JSON" -i --data-binary @- 2>/dev/null \
  | grep 'HTTP/1.1\|xception\|Content-Type' | grep -v -F  'Access-Control-Expose-Headers' | grep -v -F 'X-Datastore-Exception-Tag' | sed 's/Exception/Ex---tion/;s/HTTP\/1.1//;s/\r//' | awk '{ print $1 $2 $3 }'
echo ""
echo "INSERT WITH default_format=JSON"
echo "INSERT INTO system.numbers Select * from numbers(10);" \
  | ${DATASTORE_CURL} -sS "${CH_URL}&default_format=JSON" -i --data-binary @- 2>/dev/null \
  | grep 'HTTP/1.1\|xception\|Content-Type' | grep -v -F  'Access-Control-Expose-Headers' | grep -v -F 'X-Datastore-Exception-Tag' |  sed 's/Exception/Ex---tion/;s/HTTP\/1.1//;s/\r//' | awk '{ print $1 $2 $3 }'
echo ""
echo "INSERT WITH default_format=XML"
echo "INSERT INTO system.numbers Select * from numbers(10);" \
  | ${DATASTORE_CURL} -sS "${CH_URL}&default_format=XML" -i --data-binary @- 2>/dev/null \
  | grep 'HTTP/1.1\|xception\|Content-Type' | grep -v -F  'Access-Control-Expose-Headers' | grep -v -F 'X-Datastore-Exception-Tag' | sed 's/Exception/Ex---tion/;s/HTTP\/1.1//;s/\r//' | awk '{ print $1 $2 $3 }'
echo ""
echo "INSERT WITH default_format=BADFORMAT"
echo "INSERT INTO system.numbers Select * from numbers(10);" \
  | ${DATASTORE_CURL} -sS "${CH_URL}&default_format=BADFORMAT" -i --data-binary @- 2>/dev/null \
  | grep 'HTTP/1.1\|xception\|Content-Type' | grep -v -F  'Access-Control-Expose-Headers' | grep -v -F 'X-Datastore-Exception-Tag' | sed 's/Exception/Ex---tion/;s/HTTP\/1.1//;s/\r//' | awk '{ print $1 $2 $3 }'


echo ""
echo "SELECT missing column WITH X-Datastore-Format: JSON"
echo "SELECT x FROM system.numbers LIMIT 1;"\
  | ${DATASTORE_CURL} -sS "${CH_URL}" -H 'X-Datastore-Format: JSON' -i --data-binary @- 2>/dev/null \
  | grep 'HTTP/1.1\|xception\|Content-Type' | grep -v -F  'Access-Control-Expose-Headers' | grep -v -F 'X-Datastore-Exception-Tag' | sed 's/Exception/Ex---tion/;s/HTTP\/1.1//;s/\r//' | awk '{ print $1 $2 $3 }'
echo ""
echo "INSERT WITH X-Datastore-Format: JSON"
echo "INSERT INTO system.numbers Select * from numbers(10);" \
  | ${DATASTORE_CURL} -sS "${CH_URL}" -H 'X-Datastore-Format: JSON' -i --data-binary @- 2>/dev/null \
  | grep 'HTTP/1.1\|xception\|Content-Type' | grep -v -F  'Access-Control-Expose-Headers' | grep -v -F 'X-Datastore-Exception-Tag' | sed 's/Exception/Ex---tion/;s/HTTP\/1.1//;s/\r//' | awk '{ print $1 $2 $3 }'
echo ""
echo "INSERT WITH X-Datastore-Format: XML"
echo "INSERT INTO system.numbers Select * from numbers(10);" \
  | ${DATASTORE_CURL} -sS "${CH_URL}" -H 'X-Datastore-Format: XML' -i --data-binary @- 2>/dev/null \
  | grep 'HTTP/1.1\|xception\|Content-Type' | grep -v -F  'Access-Control-Expose-Headers' | grep -v -F 'X-Datastore-Exception-Tag' | sed 's/Exception/Ex---tion/;s/HTTP\/1.1//;s/\r//' | awk '{ print $1 $2 $3 }'
echo ""
echo "INSERT WITH X-Datastore-Format: BADFORMAT"
echo "INSERT INTO system.numbers Select * from numbers(10);" \
  | ${DATASTORE_CURL} -sS "${CH_URL}" -H 'X-Datastore-Format: BADFORMAT' -i --data-binary @- 2>/dev/null \
  | grep 'HTTP/1.1\|xception\|Content-Type' | grep -v -F  'Access-Control-Expose-Headers' | grep -v -F 'X-Datastore-Exception-Tag' | sed 's/Exception/Ex---tion/;s/HTTP\/1.1//;s/\r//' | awk '{ print $1 $2 $3 }'
