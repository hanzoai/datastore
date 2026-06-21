#!/usr/bin/env bash
# Tags: no-random-settings
# no-random-settings: we test interaction between explicit settings, compatibility, and constraints

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

USER="u_04078_${DATASTORE_DATABASE}"
PROFILE="p_04078_${DATASTORE_DATABASE}"

${DATASTORE_CLIENT} -q "DROP PROFILE IF EXISTS ${PROFILE}"
${DATASTORE_CLIENT} -q "DROP USER IF EXISTS ${USER}"
${DATASTORE_CLIENT} -q "CREATE SETTINGS PROFILE ${PROFILE} SETTINGS max_threads = 4 CONST"
${DATASTORE_CLIENT} -q "CREATE USER ${USER} SETTINGS PROFILE '${PROFILE}'"

# CONST violated
${DATASTORE_CLIENT} --user="${USER}" --compatibility='23.8' --max_threads=8 -q "SELECT 1" 2>&1 | grep -o 'SETTING_CONSTRAINT_VIOLATION' | head -1
# CONST unchanged
${DATASTORE_CLIENT} --user="${USER}" --compatibility='23.8' --max_threads=4 -q "SELECT getSetting('max_threads')"
# Explicit setting preserved despite compatibility
${DATASTORE_CLIENT} --compatibility='23.8' --enable_analyzer=1 -q "SELECT getSetting('enable_analyzer')"
# readonly=2 unchanged with compatibility
${DATASTORE_CLIENT} -q "SET readonly = 2; SELECT 1 SETTINGS compatibility = '24.12', readonly = 2"
# readonly=2 changed with compatibility
${DATASTORE_CLIENT} -q "SET readonly = 2; SELECT 1 SETTINGS compatibility = '24.12', readonly = 1" 2>&1 | grep -o 'READONLY' | head -1
# readonly=2 unchanged without compatibility
${DATASTORE_CLIENT} -q "SET readonly = 2; SELECT 1 SETTINGS readonly = 2"
# readonly=2 changed without compatibility
${DATASTORE_CLIENT} -q "SET readonly = 2; SELECT 1 SETTINGS readonly = 1" 2>&1 | grep -o 'READONLY' | head -1

${DATASTORE_CLIENT} -q "DROP USER ${USER}"
${DATASTORE_CLIENT} -q "DROP PROFILE ${PROFILE}"
