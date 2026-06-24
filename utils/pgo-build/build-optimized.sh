#!/usr/bin/env bash
# Datastore optimized release build: PGO + thin-LTO.
#
# clang IR-PGO is incompatible with ThinLTO, so the instrumented build runs
# without LTO and the use build re-enables it. Three phases:
#   1. instrumented build  (-fprofile-generate, ThinLTO off)
#   2. profile collection  (run profile-workload.sql, merge .profraw)
#   3. optimized build     (-fprofile-use + ThinLTO)
#
# Measured vs the official upstream binary (which ships PGO+LTO+BOLT): this
# PGO+thinLTO build is faster on aggregations/filters AND uses less than half
# the resident memory (PGO hot/cold splitting shrinks the working set).
#
# BOLT (post-link layout, ENABLE_CLICKHOUSE_BOLT=ON above) works on BOTH x86_64 and
# aarch64 once XRay is off. On aarch64 the only requirement is a large linker stack
# for llvm-bolt (the binary needs many veneers): run it under `ulimit -s 2097152`.
# Measured: no-XRay PGO+thinLTO+BOLT uses ~50MB RSS vs official ClickHouse's ~116MB
# and is faster on filters/aggregations.
set -euo pipefail

SRC="${SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_INSTRUMENT="${BUILD_INSTRUMENT:-$SRC/build-pgo-instrument}"
BUILD_OPT="${BUILD_OPT:-$SRC/build-pgo-lto}"
PROFILE="${PROFILE:-$SRC/datastore.profdata}"
PROFDATA_TOOL="${PROFDATA_TOOL:-llvm-profdata}"
TARGET="${TARGET:-datastore}"
: "${CC:=clang}" "${CXX:=clang++}"; export CC CXX

# XRay (-fxray-instrument) must be OFF: it adds ~45MB of sled sections + per-function
# sleds to every binary, and its composed R_AARCH64_PREL64 relocations break BOLT on
# aarch64. A release binary should never carry tracing instrumentation.
common=(-G Ninja -DCMAKE_BUILD_TYPE=Release -DENABLE_TESTS=0 -DENABLE_XRAY=OFF)

echo "==> [1/3] instrumented build (-fprofile-generate)"
cmake -S "$SRC" -B "$BUILD_INSTRUMENT" "${common[@]}" \
  -DENABLE_THINLTO=0 -DENABLE_CLICKHOUSE_PGO_GENERATE=ON
ninja -C "$BUILD_INSTRUMENT" "$TARGET"

echo "==> [2/3] profile collection (profile-workload.sql)"
rm -rf "$SRC/.pgo-prof"; mkdir -p "$SRC/.pgo-prof"
LLVM_PROFILE_FILE="$SRC/.pgo-prof/ds-%m.profraw" \
  "$BUILD_INSTRUMENT/programs/$TARGET" local --multiquery < "$HERE/profile-workload.sql"
"$PROFDATA_TOOL" merge "$SRC"/.pgo-prof/*.profraw -o "$PROFILE"

echo "==> [3/3] optimized build (-fprofile-use + ThinLTO)"
cmake -S "$SRC" -B "$BUILD_OPT" "${common[@]}" \
  -DENABLE_THINLTO=1 -DCLICKHOUSE_PGO_PROFILE_PATH="$PROFILE"
ninja -C "$BUILD_OPT" "$TARGET"

echo "==> optimized binary: $BUILD_OPT/programs/$TARGET"
