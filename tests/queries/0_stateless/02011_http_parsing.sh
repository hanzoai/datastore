#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

echo -ne 'One\nTwo\n'  | ${DATASTORE_CURL} -sSF 'metrics_list=@-;' "${DATASTORE_URL}&metrics_list_format=TSV&metrics_list_structure=Path+String&query=SELECT+*+FROM+metrics_list";
echo -ne 'Three\nFour' | ${DATASTORE_CURL} -sSF 'metrics_list=@-;' "${DATASTORE_URL}&metrics_list_format=TSV&metrics_list_structure=Path+String&query=SELECT+*+FROM+metrics_list";
echo -ne 'Five\n'      | ${DATASTORE_CURL} -sSF 'metrics_list=@-;' "${DATASTORE_URL}&metrics_list_format=TSV&metrics_list_structure=Path+String&query=SELECT+*+FROM+metrics_list";
echo -ne 'Six'         | ${DATASTORE_CURL} -sSF 'metrics_list=@-;' "${DATASTORE_URL}&metrics_list_format=TSV&metrics_list_structure=Path+String&query=SELECT+*+FROM+metrics_list";
