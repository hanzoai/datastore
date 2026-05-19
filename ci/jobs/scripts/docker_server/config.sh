#!/usr/bin/env bash

# Get current file directory
currentDir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# iterate over all directories in current path
clickhouseTests=$( find "$currentDir"/tests/ -maxdepth 1 -name 'clickhouse-*' -not -name 'clickhouse-distroless-*' -type d -exec basename {} \; )
clickhouseDistrolessTests=$( find "$currentDir"/tests/ -maxdepth 1 -name 'clickhouse-distroless-*' -type d -exec basename {} \; )
keeperTests=$( find "$currentDir"/tests/ -maxdepth 1 -name 'keeper-*' -type d -exec basename {} \; )

imageTests+=(
	['hanzoai/datastore']="${clickhouseTests}"
	['hanzoai/datastore-keeper']="${keeperTests}"
)
