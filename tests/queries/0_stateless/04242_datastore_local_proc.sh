#!/usr/bin/env bash
# Tags: linux

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# Reproduces #69070: datastore-local defaults storage_file_read_method=mmap, but /proc files
# report stat.st_size = 0, so MMappedFileDescriptor::set returns an empty buffer and
# `file('/proc/cpuinfo', 'RawBLOB')` produced an empty result with no error.
# After the fix, st_size == 0 is excluded from the mmap branch and the sequential reader
# returns the actual content.

# `notEmpty(raw_blob)` rather than `count()` so that RawBLOBRowInputFormat::countRows fast
# path cannot trivially satisfy the query without actually reading the file.
# Pin storage_file_read_method=mmap explicitly even though it is the datastore-local default,
# so the test continues to target the changed branch if the default changes later.
${DATASTORE_LOCAL} --storage_file_read_method=mmap -q "SELECT notEmpty(raw_blob) FROM file('/proc/cpuinfo', 'RawBLOB')"
