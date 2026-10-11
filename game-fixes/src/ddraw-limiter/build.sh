#!/bin/sh
# Builds the 32-bit ddraw.dll and packs it with its ini and the licence into ddraw-limiter.zip.
# Needs mingw-w64 (Debian/Ubuntu: gcc-mingw-w64-i686) and zip.
#   usage: sh build.sh [OUTPUT_DIR]   (default: ./out)
set -e
OUT=${1:-out}
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../.." && pwd)
mkdir -p "$OUT"
i686-w64-mingw32-windres "$HERE/limiter.rc" -O coff -o "$OUT/limiter.res.o"
i686-w64-mingw32-gcc -O2 -Wall -Wextra -shared -static-libgcc -Wl,--enable-stdcall-fixup \
    -o "$OUT/ddraw.dll" "$HERE/limiter.c" "$OUT/limiter.res.o" "$HERE/ddraw.def" -lwinmm
rm -f "$OUT/limiter.res.o"
cp "$HERE/ddraw-darth.ini" "$OUT/ddraw-darth.ini"
cp "$ROOT/LICENSE" "$OUT/LICENSE-ddraw-limiter.txt"
rm -f "$OUT/ddraw-limiter.zip"
(cd "$OUT" && zip -q -X ddraw-limiter.zip ddraw.dll ddraw-darth.ini LICENSE-ddraw-limiter.txt)
printf 'Built %s/ddraw-limiter.zip\n' "$OUT"
sha512sum "$OUT/ddraw-limiter.zip"
