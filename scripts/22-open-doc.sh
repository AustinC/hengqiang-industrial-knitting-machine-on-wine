#!/bin/sh
# Open a .pds document straight from the command line.
#
# The File > Open crash is reproducible this way, which makes it debuggable
# without a human driving the GUI: MFC's CCommandLineInfo turns a bare filename
# argument into the same CWinApp::OpenDocumentFile call the menu item makes.
#
# usage: 22-open-doc.sh [document] [logname]
#   document defaults to the shipped sample pds_file/LG12001.pds
#   WINEDEBUG is honoured; nothing is forced, so a bare run stays quiet.
. "$(dirname "$0")/env.sh"

APPDIR="$WINEPREFIX/drive_c/Program Files (x86)/恒强/横机制板系统（16把纱嘴）"
APP="$APPDIR/HxPDS.exe"
DOC="${1:-$APPDIR/pds_file/LG12001.pds}"
LOG="$LOGDIR/${2:-open-doc}.log"

[ -f "$APP" ] || { echo "!! not found: $APP"; exit 1; }
[ -f "$DOC" ] || { echo "!! not found: $DOC"; exit 1; }

: >"$LOG"
cd "$APPDIR" || exit 1
hq_wine "$APP" "$(winepath -w "$DOC" 2>/dev/null || echo "$DOC")" >>"$LOG" 2>&1 &

echo "launched pid $! WINEDEBUG=${WINEDEBUG:-<none>}"
echo "log: $LOG"
