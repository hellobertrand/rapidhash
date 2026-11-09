#!/bin/sh
# Compare an old rapidhash.h with a new one: bit-exactness check, then micro-benchmark.
#
#   ./compare.sh [REF] [len...]
#
#   REF   old header: git revision (default: master) or path to a rapidhash.h
#   len   optional list of input sizes for the benchmark (default: 0 B .. 512 KB sweep)
#
# Environment:
#   NEW      new header: git revision or path (default: ../../rapidhash.h, the working tree)
#   CC       compiler (default cc)
#   CFLAGS   flags for the hash code (default -O3; -O3 is prepended when no -O level is given)
#   RUN      command prefix for the benchmark, e.g. "taskset -c 2"
#   NOBENCH  set to 1 to only run the bit-exactness check
#   AA       set to 1 to benchmark the old header against itself: the gains printed are then pure
#            measurement noise (code placement, frequency), to calibrate the real comparison
#
# When the new header provides rapidhash_withPremixedSeed, every variant is still checked for
# bit-exactness, but only the premixed seed API is benchmarked (old *_withSeed vs new *_withPremixedSeed).
set -e
here=$(cd "$(dirname "$0")" && pwd)
REF=${1:-master}; [ $# -gt 0 ] && shift
NEW=${NEW:-$here/../../rapidhash.h}
CC=${CC:-cc}; CFLAGS=${CFLAGS:--O3}
case " $CFLAGS " in *" -O"*) ;; *) CFLAGS="-O3 $CFLAGS" ;; esac
B=$(mktemp -d "${TMPDIR:-/tmp}/rhcmp.XXXXXX"); trap 'rm -rf "$B"' EXIT
mkdir -p "$B/old" "$B/new"
fetch() { if [ -f "$1" ]; then cp "$1" "$2"; else git -C "$here" show "$1:rapidhash.h" > "$2"; fi; }
fetch "$REF" "$B/old/rapidhash.h"
fetch "$NEW" "$B/new/rapidhash.h"
if [ -n "$AA" ]; then cp "$B/old/rapidhash.h" "$B/new/rapidhash.h"; fi
PREMIX=; grep -q rapidhash_withPremixedSeed "$B/new/rapidhash.h" && PREMIX=-DHAS_PREMIX
ALIGN="-falign-functions=64"
$CC $CFLAGS $ALIGN -I"$B/old" -DPFX=ref -c "$here/wrap.c" -o "$B/ref.o"
$CC $CFLAGS $ALIGN -I"$B/new" -DPFX=new $PREMIX -c "$here/wrap.c" -o "$B/new.o"
$CC -O2 $PREMIX -I"$here" "$here/check.c" "$B/ref.o" "$B/new.o" -o "$B/check"
$CC -O2 $PREMIX -I"$here" "$here/mb.c"    "$B/ref.o" "$B/new.o" -o "$B/mb"
echo "== $(uname -sm) | $($CC --version 2>/dev/null | head -1) | CFLAGS=$CFLAGS | old=$REF${AA:+ | AA calibration: old vs old}"
"$B/check"
[ -n "$NOBENCH" ] || $RUN "$B/mb" "$@"
