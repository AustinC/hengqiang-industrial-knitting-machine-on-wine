#!/bin/sh
# Launch with ADO/OLEDB tracing so we can see the actual connection string and
# HRESULT behind the app's generic "调用失败" (call failed) dialog.
. "$(dirname "$0")/env.sh"

APP="$WINEPREFIX/drive_c/Program Files (x86)/恒强/横机制板系统（16把纱嘴）/HxPDS.exe"
[ -f "$APP" ] || { echo "!! not found: $APP"; exit 1; }

export WINEDEBUG="${WINEDEBUG:-+msado15,+oledb,+msi}"

: >"$LOGDIR/trace.log"
cd "$(dirname "$APP")" || exit 1
wine "$APP" >>"$LOGDIR/trace.log" 2>&1 &

echo "launched pid $! with WINEDEBUG=$WINEDEBUG"
echo "log: $LOGDIR/trace.log"
