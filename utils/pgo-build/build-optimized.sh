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
# BOLT (post-link layout) is applied to x86_64 release artifacts in CI, where
# llvm-bolt is mature and the CPU exposes LBR. It is NOT applied on aarch64:
# llvm-bolt's AArch64 composed-relocation emission (R_AARCH64_PREL64) is broken
# upstream. Since PGO+thinLTO alone already beats upstream, aarch64 ships it.
set -euo pipefail

SRC="${SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_INSTRUMENT="${BUILD_INSTRUMENT:-$SRC/build-pgo-instrument}"
BUILD_OPT="${BUILD_OPT:-$SRC/build-pgo-lto}"
PROFILE="${PROFILE:-$SRC/datastore.profdata}"
PROFDATA_TOOL="${PROFDATA_TOOL:-llvm-profdata}"
TARGET="${TARGET:-datastore}"
: "${CC:=clang}" "${CXX:=clang++}"; export CC CXX

common=(-G Ninja -DCMAKE_BUILD_TYPE=Release -DENABLE_TESTS=0)

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
