#!/bin/sh
# Install the patched msado15.dll over wine's system builtin. Run with sudo.
#
# Why this has to touch /usr: wine resolves msado15 as a *builtin*, and builtins
# are only ever loaded from wine's own install dir. Two cheaper routes were
# tried and both failed:
#   - DllOverrides msado15=native  -> wine refuses the file ("couldn't load
#     in-process dll") precisely because our build IS a wine builtin PE
#   - WINEDLLPATH=<dir>            -> silently ignored for PE builtins
#
# Reversible: the stock DLL is kept alongside as msado15.dll.stock.
# Note a wine package upgrade will overwrite this; re-run afterwards.
set -e

REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WINE_VER=$(wine --version 2>/dev/null | sed 's/^wine-//')
BUILT="$REPO/wine-src/wine-$WINE_VER/dlls/msado15/i386-windows/msado15.dll"
TARGET=/usr/lib/wine/i386-windows/msado15.dll

[ "$(id -u)" = 0 ] || { echo "!! run me with sudo"; exit 1; }
[ -f "$BUILT" ]  || { echo "!! patched build missing: $BUILT"; exit 1; }
[ -f "$TARGET" ] || { echo "!! wine builtin missing: $TARGET"; exit 1; }

case "${1:-install}" in
install)
    [ -f "$TARGET.stock" ] || { cp -p "$TARGET" "$TARGET.stock"; echo "backed up -> $TARGET.stock"; }
    cp "$BUILT" "$TARGET"
    echo "installed patched msado15.dll ($(stat -c%s "$TARGET") bytes)"
    ;;
revert)
    [ -f "$TARGET.stock" ] || { echo "!! no backup to restore"; exit 1; }
    cp -p "$TARGET.stock" "$TARGET"
    echo "reverted to stock msado15.dll"
    ;;
*)
    echo "usage: sudo $0 [install|revert]"; exit 2
    ;;
esac
