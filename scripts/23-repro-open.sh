#!/bin/sh
# One-command reproduction of the File > Open crash, start to finish, with no
# human in the loop.
#
# Opening the document from the command line is the same MFC code path as the
# menu item, and the only interaction the app then needs is dismissing its
# "This docment version is at lower level" prompt -- which is a click this
# script makes on the private display, never on the real desktop.
#
# usage: 23-repro-open.sh [document] [logname]
#   WINEDEBUG is honoured, so e.g.
#     WINEDEBUG=+seh,+loaddll scripts/23-repro-open.sh
SRC=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export DISPLAY="${HQ_XDISPLAY:-:9}"
# No window manager on the private display, so let wine stack its own windows.
export HQ_VDESKTOP="${HQ_VDESKTOP:-2400x1500}"
LOG="${SRC}/logs/${2:-open-doc}.log"

"$SRC/scripts/30-xvfb.sh" start >/dev/null || exit 1

# A previous instance holds a lock on HengJi.accdb and would change what we see.
"$SRC/scripts/apppid.sh" kill >/dev/null

"$SRC/scripts/22-open-doc.sh" "$1" "${2:-open-doc}" || exit 1

# The prompt appears once the document has been parsed far enough to know its
# version, which takes a few seconds on a cold start.
echo "waiting for the version prompt..."
i=0
while [ $i -lt 24 ]; do
    if "$SRC/scripts/ui.sh" find 'Hint|提示' 2>/dev/null | grep -q .; then
        break
    fi
    i=$((i + 1)); sleep 0.5
done
# Only documents saved by an older version ask; newer ones load straight
# through, so a missing prompt is not an error.
if "$SRC/scripts/ui.sh" find 'Hint|提示' | grep -q .; then
    "$SRC/scripts/ui.sh" click 177 100 'Hint|提示' || exit 1
else
    echo "(no prompt -- document is current-format)"
fi

# Give the document load a chance to finish or fall over.
sleep 8

echo
if grep -q "err:seh\|Unhandled" "$LOG"; then
    echo "CRASHED:"
    grep -n "err:seh\|Unhandled" "$LOG" | tail -5
else
    echo "no crash recorded in $LOG"
fi
echo
echo "windows now:"
"$SRC/scripts/ui.sh" find
