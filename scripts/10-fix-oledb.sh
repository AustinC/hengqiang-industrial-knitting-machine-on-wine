#!/bin/sh
# Root-cause fix for the app's "调用失败" dialog.
#
# The app connects with:
#   Provider=Microsoft.ACE.OLEDB.12.0;Data Source=...;Jet OLEDB:Database Password=...
#
# Wine's builtin oledb32 (which implements MSDAINITIALIZE, the connection-string
# parser the app uses) handles only standard OLE DB init properties. Any
# provider-specific "Jet OLEDB:*" keyword makes IDataInitialize::GetDataSource
# fail with E_FAIL (0x80004005) -- proven by dbtest3.vbs, where a *wrong*
# password fails identically to the correct one, and an unrelated
# "Jet OLEDB:Engine Type" property fails the same way.
#
# Installing native MDAC 2.8 supplies Microsoft's real oledb32.dll, which
# resolves provider-specific properties against the provider itself.
set -e
. "$(dirname "$0")/env.sh"
export LANG=C LC_ALL=C

echo "==> installing native MDAC 2.8 (provides oledb32.dll)"
winetricks -q mdac28 >"$LOGDIR/mdac28.log" 2>&1 || echo "(mdac28 exit $?; see $LOGDIR/mdac28.log)"
wineserver -w

echo "==> oledb32 files present:"
find "$WINEPREFIX/drive_c/windows" -iname "oledb32*.dll" -o -iname "msdat*.dll" 2>/dev/null | head

echo "==> dll overrides:"
wine reg query 'HKCU\Software\Wine\DllOverrides' 2>/dev/null | grep -iE "oledb|msdat|msado" || echo "(none set)"
