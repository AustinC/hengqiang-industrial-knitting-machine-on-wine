#!/bin/sh
# Swap wine's builtin oledb32 for MDAC 2.8's native one.
#
# Why only oledb32 and not all of MDAC: dbtest3.vbs proved the failure is
# specifically in the connection-string -> DBPROP translation done by
# MSDAINITIALIZE (in oledb32). ACE itself is fine -- a bare connection reaches
# it and it correctly reports "Not a valid password". So we replace the one
# component that's broken and leave wine's builtin msado15/ADO in place.
#
# MSDAINITIALIZE is already registered at Common Files\System\OLE DB\oledb32.dll,
# where wine put a stub PE that forwards to its builtin .so. Dropping the real
# PE there plus a native override makes wine load Microsoft's implementation.
set -e
. "$(dirname "$0")/env.sh"
export LANG=C LC_ALL=C

NATIVE="$SRC/downloads/mdac_x/native"
OLEDB_DIR="$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System/OLE DB"

[ -f "$NATIVE/oledb32.dll" ] || { echo "!! extract MDAC first (missing $NATIVE/oledb32.dll)"; exit 1; }
[ -d "$OLEDB_DIR" ] || { echo "!! missing $OLEDB_DIR"; exit 1; }

echo "==> backing up wine's stub oledb32.dll"
[ -f "$OLEDB_DIR/oledb32.dll.wine-builtin" ] || \
    cp -p "$OLEDB_DIR/oledb32.dll" "$OLEDB_DIR/oledb32.dll.wine-builtin"

echo "==> installing native oledb32 / oledb32r / msdatl3"
cp -p "$NATIVE/oledb32.dll"  "$OLEDB_DIR/oledb32.dll"
cp -p "$NATIVE/oledb32r.dll" "$OLEDB_DIR/oledb32r.dll"
cp -p "$NATIVE/msdatl3.dll"  "$OLEDB_DIR/msdatl3.dll"

echo "==> setting native dll overrides"
for d in oledb32 msdatl3; do
    wine reg add 'HKCU\Software\Wine\DllOverrides' /v "$d" /t REG_SZ /d native /f >/dev/null 2>&1
done
wineserver -w

echo "==> registering native oledb32 + msdatl3"
wine regsvr32 /s 'C:\Program Files (x86)\Common Files\System\OLE DB\msdatl3.dll'  >/dev/null 2>&1 || true
wine regsvr32 /s 'C:\Program Files (x86)\Common Files\System\OLE DB\oledb32.dll' >/dev/null 2>&1 || true
wineserver -w

echo "==> verifying"
file "$OLEDB_DIR/oledb32.dll" | sed 's/.*: //'
wine reg query 'HKLM\Software\Classes\Wow6432Node\CLSID\{2206CDB0-19C1-11D1-89E0-00C04FD7A829}\InprocServer32' 2>/dev/null | grep -i "REG_SZ"
wine reg query 'HKCU\Software\Wine\DllOverrides' 2>/dev/null | grep -iE "oledb32|msdatl3"
