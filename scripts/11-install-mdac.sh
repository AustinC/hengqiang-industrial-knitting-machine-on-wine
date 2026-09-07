#!/bin/sh
# Install native MDAC 2.8 by hand.
#
# winetricks refuses this verb on any win64 prefix, but that guard is blanket:
# MDAC's payload is 32-bit and lands correctly in syswow64 / Common Files (x86)
# under wow64. We need it because native oledb32.dll re-registers MSDAINITIALIZE
# to Common Files\System\Ole DB\oledb32.dll, displacing wine's builtin whose
# connection-string parser can't pass "Jet OLEDB:*" properties through to ACE.
#
# MDAC 2.8 checks the OS version and refuses on modern ones, hence the
# temporary nt40 winver (same trick winetricks uses).
set -e
. "$(dirname "$0")/env.sh"
export LANG=C LC_ALL=C

PKG="$SRC/downloads/MDAC_TYP.EXE"
[ -f "$PKG" ] || { echo "!! missing $PKG"; exit 1; }

RESTORE_WINVER="${RESTORE_WINVER:-win10}"

echo "==> temporarily setting winver to nt40"
winetricks -q nt40 >"$LOGDIR/mdac-winver.log" 2>&1 || echo "(nt40 exit $?)"
wineserver -w

echo "==> running MDAC installer (silent)"
cd "$SRC/downloads"
wine "$PKG" /q /C:"setup /qnt" >"$LOGDIR/mdac-install.log" 2>&1 || echo "(installer exit $?)"
wineserver -w

echo "==> restoring winver to $RESTORE_WINVER"
winetricks -q "$RESTORE_WINVER" >>"$LOGDIR/mdac-winver.log" 2>&1 || echo "($RESTORE_WINVER exit $?)"
wineserver -w

echo "==> overriding ADO/ODBC to native (mirrors winetricks load_native_mdac)"
for d in msado15 odbccp32; do
    wine reg add 'HKCU\Software\Wine\DllOverrides' /v "$d" /t REG_SZ /d "native,builtin" /f >/dev/null 2>&1
done
wineserver -w

echo "==> native oledb32 / ADO files:"
find "$WINEPREFIX/drive_c" -iname "oledb32.dll" -o -iname "msado15.dll" -o -iname "msado27.tlb" 2>/dev/null | head

echo "==> MSDAINITIALIZE registration now points to:"
wine reg query 'HKLM\Software\Classes\Wow6432Node\CLSID\{2206CDB0-19C1-11D1-89E0-00C04FD7A829}\InprocServer32' 2>/dev/null | grep -i REG_SZ
