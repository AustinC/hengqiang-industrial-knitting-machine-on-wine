#!/bin/sh
# Install our patched msado15.dll into the prefix.
#
# ADODB.Connection's InprocServer32 already points at
#   C:\Program Files (x86)\Common Files\System\ADO\msado15.dll
# and the file sitting there is a normal wine-builtin PE (byte-identical to
# /usr/lib/wine/i386-windows/msado15.dll). So replacing that one file is enough
# -- no DllOverrides change, and nothing outside the prefix is touched.
set -e
. "$(dirname "$0")/env.sh"
export LANG=C LC_ALL=C

WINE_VER=$(wine --version 2>/dev/null | sed 's/^wine-//')
BUILT="$SRC/wine-src/wine-$WINE_VER/dlls/msado15/i386-windows/msado15.dll"
ADO_DIR="$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System/ADO"
[ -d "$ADO_DIR" ] || ADO_DIR="$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System/ado"

[ -f "$BUILT" ] || { echo "!! not built: $BUILT"; exit 1; }

echo "==> wine version sanity check"
sysver=$(wine --version 2>/dev/null)
echo "   system wine: $sysver (patches are built against whatever is installed)"

echo "==> backing up stock msado15.dll"
[ -f "$ADO_DIR/msado15.dll.stock" ] || cp -p "$ADO_DIR/msado15.dll" "$ADO_DIR/msado15.dll.stock"

echo "==> installing patched build"
cp "$BUILT" "$ADO_DIR/msado15.dll"

echo "==> installed:"
ls -la "$ADO_DIR/msado15.dll" "$ADO_DIR/msado15.dll.stock"
