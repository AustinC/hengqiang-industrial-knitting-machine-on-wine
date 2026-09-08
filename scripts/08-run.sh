#!/bin/sh
# Launch HQ-PDS16. Logs to logs/run.log so failures are inspectable after the
# fact rather than scrolling past in a terminal.
. "$(dirname "$0")/env.sh"

APP="$WINEPREFIX/drive_c/Program Files (x86)/恒强/横机制板系统（16把纱嘴）/HxPDS.exe"

[ -f "$APP" ] || { echo "!! not found: $APP"; exit 1; }

: >"$LOGDIR/run.log"
cd "$(dirname "$APP")" || exit 1
hq_wine "$APP" >>"$LOGDIR/run.log" 2>&1 &

echo "launched; pid $!"
echo "log: $LOGDIR/run.log"
