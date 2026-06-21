#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

echo -ne '1,Hello\n2,World\n' | ${DATASTORE_CURL} -sSF 'file=@-' "${DATASTORE_URL}&query=SELECT+*+FROM+file&file_format=CSV&file_types=UInt8,String";
echo -ne '1@Hello\n2@World\n' | ${DATASTORE_CURL} -sSF 'file=@-' "${DATASTORE_URL}&query=SELECT+*+FROM+file&file_format=CSV&file_types=UInt8,String&format_csv_delimiter=@";
echo -ne '\x01\x00\x00\x00\x02\x00\x00\x00' | ${DATASTORE_CURL} -sSF "tmp=@-" "${DATASTORE_URL}&query=SELECT+*+FROM+tmp&tmp_structure=TaskID+UInt32&tmp_format=RowBinary";
