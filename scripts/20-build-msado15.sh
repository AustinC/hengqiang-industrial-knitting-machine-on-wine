#!/bin/sh
# Fetch wine source matching the installed runtime, apply our msado15 patches,
# and build just the 32-bit msado15.dll.
#
# Only msado15 is built (~10s), not the whole tree -- the app is 32-bit so
# i386-windows is the arch that matters. clang+lld serve as the PE
# cross-compiler, so mingw-w64 (a ~1.2GB install) is not needed.
set -e
. "$(dirname "$0")/env.sh"
export LANG=C LC_ALL=C

V=$(wine --version 2>/dev/null | sed 's/^wine-//')
[ -n "$V" ] || { echo "!! cannot determine wine version"; exit 1; }
SRCDIR="$SRC/wine-src/wine-$V"
TARBALL="$SRC/wine-src/wine-$V.tar.xz"
MAJOR=${V%%.*}

mkdir -p "$SRC/wine-src"

if [ ! -d "$SRCDIR" ]; then
    if [ ! -f "$TARBALL" ]; then
        echo "==> downloading wine $V source"
        curl -sSL --max-time 900 -o "$TARBALL" \
            "https://dl.winehq.org/wine/source/$MAJOR.x/wine-$V.tar.xz"
    fi
    echo "==> extracting"
    ( cd "$SRC/wine-src" && tar xf "$TARBALL" )
fi

echo "==> applying patches"
cd "$SRCDIR"
for p in "$SRC"/patches/*.patch; do
    if patch -p1 --dry-run -R < "$p" >/dev/null 2>&1; then
        echo "   already applied: $(basename "$p")"
    else
        patch -p1 < "$p" >/dev/null && echo "   applied: $(basename "$p")"
    fi
done

if [ ! -f Makefile ]; then
    echo "==> configure (clang/lld for PE; only msado15 gets built so the"
    echo "    missing X/freetype dev headers here do not matter)"
    ./configure --enable-archs=i386,x86_64 --disable-tests --without-x --without-freetype \
        > "$LOGDIR/configure.log" 2>&1
fi

echo "==> building dlls/msado15/i386-windows/msado15.dll"
make -j"$(nproc)" dlls/msado15/i386-windows/msado15.dll > "$LOGDIR/build.log" 2>&1

ls -la dlls/msado15/i386-windows/msado15.dll
echo
echo "next: sudo $SRC/scripts/18-install-patched-msado15-system.sh"
