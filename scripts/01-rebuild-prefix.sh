#!/bin/sh
# Nuke and rebuild the wine prefix from scratch with the Chinese locale active
# so the ANSI codepage lands on 936, plus HiDPI scaling.
set -e
. "$(dirname "$0")/env.sh"

echo "==> killing any running wineserver"
wineserver -k 2>/dev/null || true
sleep 1

echo "==> removing $WINEPREFIX"
rm -rf "$WINEPREFIX"

echo "==> creating fresh prefix (LANG=$LANG)"
# mscoree/mshtml disabled: this app needs neither .NET nor an HTML control,
# and it stops wineboot stalling on those components.
WINEDLLOVERRIDES="mscoree,mshtml=" wineboot -u >"$LOGDIR/wineboot.log" 2>&1

echo "==> setting DPI to $DPI"
wine reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d "$DPI" /f >/dev/null 2>&1
wine reg add 'HKLM\System\CurrentControlSet\Hardware Profiles\Current\Software\Fonts' \
    /v LogPixels /t REG_DWORD /d "$DPI" /f >/dev/null 2>&1

wineserver -w

echo "==> verifying locale/codepage"
"$(dirname "$0")/02-check-codepage.sh"
