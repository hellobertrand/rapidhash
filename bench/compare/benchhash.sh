#!/bin/sh
# Compare an old rapidhash.h with a new one using the official benchmark (bench/benchHash, from xxHash).
# Unlike compare.sh, this also measures random input lengths, where branch mispredictions count.
#
#   ./benchhash.sh [REF] [benchHash options...]
#
#   REF      old header: git revision (default: master) or path to a rapidhash.h
#   options  passed to benchHash (default: --mins=1 --maxs=64 --minl=8 --maxl=20)
#            --mins/--maxs: small sizes in bytes, --minl/--maxl: large sizes as log2(bytes)
#
# Environment:
#   NEW      new header: git revision or path (default: ../../rapidhash.h, the working tree)
#   HASHES   hashes to run (default: rapidhash; also rapidhashMicro, rapidhashNano)
#   REPS     old/new rounds, the best result of each is kept (default: 1)
#   CC       compiler (default cc)
#   CFLAGS   flags (default -O3; -O3 is prepended when no -O level is given)
#   RUN      command prefix for the benchmark, e.g. "taskset -c 2"
#   AA       set to 1 to benchmark the old header against itself (measurement noise)
#   XXHASH   path to xxhash.h; by default v0.8.3 is downloaded once and cached
#   OUT      directory where the raw benchHash outputs are kept (default: a temporary directory)
#
# Each measurement takes about 0.5 s: with the defaults, count ~2.5 min per header.
# Gains are positive when the new header is faster.
set -e
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
REF=${1:-master}; [ $# -gt 0 ] && shift
[ $# -gt 0 ] || set -- --mins=1 --maxs=64 --minl=8 --maxl=20
NEW=${NEW:-$root/rapidhash.h}
HASHES=${HASHES:-rapidhash}
REPS=${REPS:-1}
CC=${CC:-cc}; CFLAGS=${CFLAGS:--O3}
case " $CFLAGS " in *" -O"*) ;; *) CFLAGS="-O3 $CFLAGS" ;; esac

B=$(mktemp -d "${TMPDIR:-/tmp}/rhbench.XXXXXX"); trap 'rm -rf "$B"' EXIT
OUT=${OUT:-$B/out}
mkdir -p "$B/old" "$B/new" "$B/xx" "$OUT"
fetch() { if [ -f "$1" ]; then cp "$1" "$2"; else git -C "$here" show "$1:rapidhash.h" > "$2"; fi; }
fetch "$REF" "$B/old/rapidhash.h"
fetch "$NEW" "$B/new/rapidhash.h"
if [ -n "$AA" ]; then cp "$B/old/rapidhash.h" "$B/new/rapidhash.h"; fi

# xxhash.h, needed by bench/hashes.h (pinned version, checked by SHA-256)
XXH_SHA=17973c0dc49d9854ca26caa191f0e12f7a424b68858d9a78de3860d959d85e4b
sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }
if [ -z "$XXHASH" ]; then
  XXHASH=${XDG_CACHE_HOME:-$HOME/.cache}/rapidhash-bench/xxhash-0.8.3.h
  if [ ! -f "$XXHASH" ]; then
    mkdir -p "$(dirname "$XXHASH")"
    url=https://raw.githubusercontent.com/Cyan4973/xxHash/v0.8.3/xxhash.h
    if command -v curl >/dev/null; then curl -fsSL -o "$XXHASH.tmp" "$url"; else wget -q -O "$XXHASH.tmp" "$url"; fi
    [ "$(sha256 "$XXHASH.tmp")" = "$XXH_SHA" ] || { echo "xxhash.h: unexpected SHA-256" >&2; rm -f "$XXHASH.tmp"; exit 1; }
    mv "$XXHASH.tmp" "$XXHASH"
  fi
fi
cp "$XXHASH" "$B/xx/xxhash.h"

src="$root/bench/main.c $root/bench/bhDisplay.c $root/bench/benchHash.c $root/bench/benchfn.c $root/bench/timefn.c"
for v in old new; do
  # shellcheck disable=SC2086
  $CC $CFLAGS -std=c99 -I"$B/$v" -I"$B/xx" $src -o "$B/bh_$v"
done

echo "== $(uname -sm) | $($CC --version 2>/dev/null | head -1) | CFLAGS=$CFLAGS | old=$REF | new=$NEW${AA:+ | AA calibration: old vs old}"
echo "== benchHash $* | hashes: $HASHES | reps: $REPS | raw outputs: $OUT"
r=1
while [ "$r" -le "$REPS" ]; do
  for h in $HASHES; do
    for v in old new; do
      echo "   round $r: $h ($v)" >&2
      $RUN "$B/bh_$v" "$@" "$h" > "$OUT/$v.$h.$r.txt"
    done
  done
  r=$((r + 1))
done

# Summary: best of REPS for each point; small sizes grouped into ranges (geometric mean of the gains).
awk -v hashes="$HASHES" '
function grp(n) { return n<=3?"1-3":n<=7?"4-7":n<=16?"8-16":n<=32?"17-32":n<=64?"33-64":n<=112?"65-112":n<=256?"113-256":">256" }
function human(l,  b) { b = 2^l; return b>=1048576 ? b/1048576 " MB" : b>=1024 ? b/1024 " KB" : b " B" }
FNR == 1 { split(FILENAME, p, "/"); split(p[length(p)], q, "."); v = q[1] }
/benchmarking large inputs/ { s = "large"; match($0, /\(log[0-9]+\)/); first = substr($0, RSTART+4, RLENGTH-5) + 0; next }
/Throughput small inputs of fixed size/ { s = "thr fixed"; match($0, /from [0-9]+/); first = substr($0, RSTART+5, RLENGTH-5) + 0; mins = first; next }
/benchmarking random size inputs/ { s = "thr random [1-N]"; first = mins; next }
/Latency for small inputs of fixed size/ { s = "lat fixed"; first = mins; next }
/Latency for small inputs of random size/ { s = "lat random [1-N]"; first = mins; next }
s != "" && /,/ {
  n = split($0, f, ","); h = f[1]; gsub(/ /, "", h)
  for (i = 2; i <= n; i++) {
    k = s SUBSEP h SUBSEP (first + i - 2); x = f[i] + 0
    if (!((v, k) in best) || x > best[v, k]) best[v, k] = x
    if (!(k in seen)) { seen[k] = 1; order[++no] = k }
  }
}
END {
  nh = split(hashes, H, " ")
  printf "\nlarge inputs (MB/s)\n%-15s %8s | %9s %9s %7s\n", "hash", "size", "old", "new", "gain"
  for (j = 1; j <= nh; j++) for (o = 1; o <= no; o++) {
    split(order[o], c, SUBSEP); if (c[1] != "large" || c[2] != H[j]) continue
    a = best["old", order[o]]; b = best["new", order[o]]
    if (a > 0 && b > 0) printf "%-15s %8s | %9.0f %9.0f %+6.1f%%\n", H[j], human(c[3]), a, b, (b/a - 1)*100
  }
  ns = split("thr fixed|thr random [1-N]|lat fixed|lat random [1-N]", S, "|")
  for (t = 1; t <= ns; t++) {
    printf "\n%s (ns per hash, mean over each size range; gain = geometric mean)\n%-15s %8s | %9s %9s %7s\n", S[t], "hash", "bytes", "old", "new", "gain"
    for (j = 1; j <= nh; j++) {
      ng = 0; delete G; delete so; delete sn; delete sl; delete cnt
      for (o = 1; o <= no; o++) {
        split(order[o], c, SUBSEP); if (c[1] != S[t] || c[2] != H[j]) continue
        a = best["old", order[o]]; b = best["new", order[o]]; if (a <= 0 || b <= 0) continue
        g = grp(c[3] + 0); if (!(g in cnt)) G[++ng] = g
        cnt[g]++; so[g] += 1e9/a; sn[g] += 1e9/b; sl[g] += log(b/a)
      }
      for (gi = 1; gi <= ng; gi++) { g = G[gi]
        printf "%-15s %8s | %9.2f %9.2f %+6.1f%%\n", H[j], g, so[g]/cnt[g], sn[g]/cnt[g], (exp(sl[g]/cnt[g]) - 1)*100 }
    }
  }
}' "$OUT"/old.*.txt "$OUT"/new.*.txt
