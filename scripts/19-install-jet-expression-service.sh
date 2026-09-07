#!/bin/sh
# Install the VBA/Jet expression service (vbajet32.dll + expsrv.dll).
#
# Access Runtime ships ACEES.DLL (ACE's expression service) but *not* the
# VBAJET32.DLL that it loads at runtime. Without it, wine logs:
#     warn:module:load_dll Failed to load module L"VBAJET32.DLL"; status=c0000135
# and ACE fails any query needing general expression evaluation with
# DB_E_ERRORSINCOMMAND / "Internal OLE Automation error".
#
# The tell is which queries survive: predicates ACE can answer from an index
# (ID = ..., FactoryId = ..., Name = '...') work, while anything needing a scan
# or arithmetic (Type = 0, Width > 0, even a constant 1 = 1) fails. That is the
# expression service missing, not bad SQL.
#
# Both DLLs come out of MDAC 2.8's jetfiles.cab.
set -e
. "$(dirname "$0")/env.sh"
export LANG=C LC_ALL=C

CAB="$SRC/downloads/mdac_x/jetfiles.cab"
STAGE="$SRC/downloads/mdac_x/jet"
SYSWOW="$WINEPREFIX/drive_c/windows/syswow64"

[ -f "$CAB" ] || { echo "!! missing $CAB (run 12-native-oledb32.sh prerequisites first)"; exit 1; }

echo "==> extracting expression service from jetfiles.cab"
mkdir -p "$STAGE"
cabextract -q -d "$STAGE" -F vbajet32.dll -F expsrv.dll "$CAB" >/dev/null 2>&1

for f in vbajet32.dll expsrv.dll; do
    [ -f "$STAGE/$f" ] || { echo "!! $f not extracted"; exit 1; }
    cp -p "$STAGE/$f" "$SYSWOW/$f"
    echo "   installed $f"
done

echo "==> verifying ACE can now evaluate a non-indexed predicate"
echo "   (expects OK for 'WHERE 1 = 1' style queries; see C:\\dbtest7.vbs)"
ls -la "$SYSWOW/vbajet32.dll" "$SYSWOW/expsrv.dll"
