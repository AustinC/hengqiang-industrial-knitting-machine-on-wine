#!/bin/sh
# Private X display for driving the app without touching the real desktop.
#
# Two problems this solves at once.
#
# Capturing: X only hands back pixels that are actually on screen, so a window
# sitting behind a fullscreen terminal cannot be screenshotted at all -- both
# `import` and ffmpeg's x11grab fail with BadMatch. The app's window is nearly
# fullscreen, so on a real desktop it is almost always covered. Nothing is ever
# in front of anything on a display with no other clients.
#
# Input: clicking here cannot disturb whatever is happening on :0. ui.sh
# refuses to send input to the real display for that reason.
#
# usage: 30-xvfb.sh {start|stop|status}
#   HQ_XDISPLAY  display to create   (default :9)
#   HQ_XSIZE     screen geometry     (default 2560x1600x24)
SRC=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LOGDIR="${HQ_LOGDIR:-$SRC/logs}"
mkdir -p "$LOGDIR"

XDISPLAY="${HQ_XDISPLAY:-:9}"
XSIZE="${HQ_XSIZE:-2560x1600x24}"
PIDFILE="$LOGDIR/xvfb${XDISPLAY#:}.pid"

running() {
    [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

case "${1:-status}" in
start)
    if running; then
        echo "already running on $XDISPLAY (pid $(cat "$PIDFILE"))"
    else
        command -v Xvfb >/dev/null || {
            echo "!! Xvfb not installed: sudo pacman -S xorg-server-xvfb"; exit 1; }
        # -nolisten tcp: no reason to expose this beyond the local socket.
        Xvfb "$XDISPLAY" -screen 0 "$XSIZE" -nolisten tcp \
            >"$LOGDIR/xvfb.log" 2>&1 &
        echo $! >"$PIDFILE"
        # Xvfb takes a moment to create the socket; anything launched before
        # then just fails to connect.
        i=0
        while [ $i -lt 50 ]; do
            [ -e "/tmp/.X11-unix/X${XDISPLAY#:}" ] && break
            i=$((i + 1)); sleep 0.1
        done
        echo "started $XDISPLAY ($XSIZE) pid $(cat "$PIDFILE")"
    fi
    echo
    echo "use it with:  export DISPLAY=$XDISPLAY"
    ;;
stop)
    if running; then
        kill "$(cat "$PIDFILE")" && rm -f "$PIDFILE"
        echo "stopped $XDISPLAY"
    else
        rm -f "$PIDFILE"
        echo "not running"
    fi
    ;;
status)
    if running; then
        echo "running on $XDISPLAY, pid $(cat "$PIDFILE")"
    else
        echo "not running"
    fi
    ;;
*)
    sed -n '/^# usage:/,/^$/p' "$0"
    exit 1
    ;;
esac
