#!/bin/sh
# Undo 13-native-ado.sh.
#
# MDAC 2.8's msado15 turned out to be a regression, not a fix: with it in place
# even CreateObject("ADODB.Connection") fails, because it wants CLSID
# {6c736db1-bd94-11d0-8a23-00aa00b58e10} at creation time and that class ships
# in no part of MDAC 2.8 (checked every cab and every .inf in the package).
#
# Keep native oledb32 (that one is a real, verified win -- it's what made
# "Jet OLEDB:Database Password" work) and go back to wine's builtin ADO.
set -e
. "$(dirname "$0")/env.sh"
export LANG=C LC_ALL=C

ADO_DIR="$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System/ADO"
[ -d "$ADO_DIR" ] || ADO_DIR="$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System/ado"

echo "==> dropping msado15 native override"
wine reg delete 'HKCU\Software\Wine\DllOverrides' /v msado15 /f >/dev/null 2>&1 || true

echo "==> restoring wine's builtin msado15 stub"
if [ -f "$ADO_DIR/msado15.dll.wine-builtin" ]; then
    cp -p "$ADO_DIR/msado15.dll.wine-builtin" "$ADO_DIR/msado15.dll"
    echo "   restored from backup"
fi

echo "==> re-registering builtin ADO so ADODB.* points back at wine's"
wine regsvr32 /s 'C:\windows\syswow64\msado15.dll' >/dev/null 2>&1 || true
wineserver -w

echo "==> ADODB.Connection now resolves to:"
wine reg query 'HKLM\Software\Classes\Wow6432Node\CLSID\{00000514-0000-0010-8000-00AA006D2EA4}\InprocServer32' 2>/dev/null | grep -i REG_SZ
echo "==> remaining overrides:"
wine reg query 'HKCU\Software\Wine\DllOverrides' 2>/dev/null | grep -iE "msado15|oledb32|msdart|msdatl3" || echo "(none)"
