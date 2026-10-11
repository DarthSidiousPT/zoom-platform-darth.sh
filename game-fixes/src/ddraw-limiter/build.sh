#!/bin/sh
# Builds the 32-bit ddraw.dll and packs it with its ini and the licence into ddraw-limiter.zip.
# Needs mingw-w64 (Debian/Ubuntu: gcc-mingw-w64-i686) and zip.
#   usage: sh build.sh [OUTPUT_DIR]   (default: ./out)
# The same source and the same compiler give the same bytes: the DLL has a fixed base address and
# no build time, and the zip has fixed file times, so the SHA-512 can be pinned in a fix file.
set -e
OUT=${1:-out}
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../.." && pwd)
mkdir -p "$OUT"
i686-w64-mingw32-windres "$HERE/limiter.rc" -O coff -o "$OUT/limiter.res.o"
i686-w64-mingw32-gcc -O2 -Wall -Wextra -shared -static-libgcc -s \
    -Wl,--enable-stdcall-fixup -Wl,--no-insert-timestamp -Wl,--image-base=0x10000000 \
    -o "$OUT/ddraw.dll" "$HERE/limiter.c" "$OUT/limiter.res.o" "$HERE/ddraw.def" -lwinmm
rm -f "$OUT/limiter.res.o"
cp "$HERE/ddraw-darth.ini" "$OUT/ddraw-darth.ini"
cp "$ROOT/LICENSE" "$OUT/LICENSE-ddraw-limiter.txt"
for f in ddraw.dll ddraw-darth.ini LICENSE-ddraw-limiter.txt; do touch -d '2026-01-01 00:00:00 UTC' "$OUT/$f"; done
rm -f "$OUT/ddraw-limiter.zip"
(cd "$OUT" && TZ=UTC zip -q -X -D -9 ddraw-limiter.zip ddraw.dll ddraw-darth.ini LICENSE-ddraw-limiter.txt)
printf 'Built %s/ddraw-limiter.zip\n' "$OUT"
sha512sum "$OUT/ddraw-limiter.zip"
