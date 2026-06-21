#!/usr/bin/env bash

# Get current file directory
currentDir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# iterate over all directories in current path
clickhouseTests=$( find "$currentDir"/tests/ -maxdepth 1 -name 'datastore-*' -not -name 'datastore-distroless-*' -type d -exec basename {} \; )
clickhouseDistrolessTests=$( find "$currentDir"/tests/ -maxdepth 1 -name 'datastore-distroless-*' -type d -exec basename {} \; )
keeperTests=$( find "$currentDir"/tests/ -maxdepth 1 -name 'keeper-*' -type d -exec basename {} \; )

imageTests+=(
	['datastore/datastore-server']="${clickhouseTests}"
	['datastore/datastore-server:distroless']="${clickhouseTests} ${clickhouseDistrolessTests}"
	['datastore/datastore-keeper']="${keeperTests}"
	['datastore/datastore-keeper:distroless']="${keeperTests}"
)
