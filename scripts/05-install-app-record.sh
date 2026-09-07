#!/bin/sh
# First-pass install of HQ-PDS16 in InstallShield RECORD mode.
#
# The GUI still appears and has to be clicked through once, but /r captures
# every answer into setup.iss. After that, 06-install-app-silent.sh can replay
# the whole install with zero interaction -- which matters because we may
# rebuild this prefix several more times while chasing the dongle/runtime bits.
set -e
. "$(dirname "$0")/env.sh"

ISS_WIN='C:\setup.iss'
ISS_UNIX="$WINEPREFIX/drive_c/setup.iss"

rm -f "$ISS_UNIX"

echo "==> launching installer in record mode"
echo "    response file will be written to $ISS_UNIX"
wine "$APP_INSTALLER" /r /f1"$ISS_WIN" >"$LOGDIR/app-install-record.log" 2>&1
wineserver -w

if [ -f "$ISS_UNIX" ]; then
    echo "==> recorded response file:"
    sed -n '1,40p' "$ISS_UNIX"
else
    echo "!! no setup.iss produced -- record mode may be unsupported"
fi
