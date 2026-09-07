#!/bin/sh
# Replay the recorded install with no GUI. Requires 05-install-app-record.sh
# to have produced C:\setup.iss first.
set -e
. "$(dirname "$0")/env.sh"

ISS_WIN='C:\setup.iss'
ISS_UNIX="$WINEPREFIX/drive_c/setup.iss"

[ -f "$ISS_UNIX" ] || { echo "!! $ISS_UNIX missing; run 05-install-app-record.sh first"; exit 1; }

echo "==> silent install from recorded response file"
wine "$APP_INSTALLER" /s /f1"$ISS_WIN" /f2'C:\setup-silent.log' \
    >"$LOGDIR/app-install-silent.log" 2>&1 || echo "(setup.exe exit $?)"
wineserver -w

echo "==> InstallShield result code (0 = success):"
tr -d '\r' < "$WINEPREFIX/drive_c/setup-silent.log" 2>/dev/null | grep -i resultcode || \
    echo "(no ResultCode line found)"
