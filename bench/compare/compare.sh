#!/bin/sh
# Compare an old rapidhash.h with the current one: bit-exactness check, then micro-benchmark.
#
#   ./compare.sh [REF] [len...]
#
#   REF   git revision (default: master) or path to an old rapidhash.h
#   len   optional list of input sizes for the benchmark (default: 0 B .. 512 KB sweep)
#
# Environment: CC (default cc), CFLAGS (default -O3), NEW (default ../../rapidhash.h),
#              RUN (command prefix, e.g. "taskset -c 2"), NOBENCH=1 to only run the check,
#              AA=1 to benchmark the old header against itself: the gains printed are then pure
#              measurement noise (code placement, frequency), to calibrate the real comparison.
set -e
here=$(cd "$(dirname "$0")" && pwd)
REF=${1:-master}; [ $# -gt 0 ] && shift
CC=${CC:-cc}; CFLAGS=${CFLAGS:--O3}
NEW=${NEW:-$here/../../rapidhash.h}
B=$(mktemp -d "${TMPDIR:-/tmp}/rhcmp.XXXXXX"); trap 'rm -rf "$B"' EXIT
mkdir -p "$B/old" "$B/new"
if [ -f "$REF" ]; then cp "$REF" "$B/old/rapidhash.h"
else git -C "$here" show "$REF:rapidhash.h" > "$B/old/rapidhash.h"; fi
cp "$NEW" "$B/new/rapidhash.h"
if [ -n "$AA" ]; then cp "$B/old/rapidhash.h" "$B/new/rapidhash.h"; fi
ALIGN="-falign-functions=64"
$CC $CFLAGS $ALIGN -I"$B/old" -DPFX=ref -c "$here/wrap.c" -o "$B/ref.o"
$CC $CFLAGS $ALIGN -I"$B/new" -DPFX=new -c "$here/wrap.c" -o "$B/new.o"
$CC -O2 -I"$here" "$here/check.c" "$B/ref.o" "$B/new.o" -o "$B/check"
$CC -O2 -I"$here" "$here/mb.c"    "$B/ref.o" "$B/new.o" -o "$B/mb"
echo "== $(uname -sm) | $($CC --version 2>/dev/null | head -1) | CFLAGS=$CFLAGS | old=$REF${AA:+ | AA calibration: old vs old}"
"$B/check"
[ -n "$NOBENCH" ] || $RUN "$B/mb" "$@"
