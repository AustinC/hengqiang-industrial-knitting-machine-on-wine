#!/bin/sh
# Locate (or kill) the actual app process.
#
# `pgrep -f` on the app name matches three processes -- the start.exe wrapper,
# the wine explorer hosting the virtual desktop, and the app itself -- and the
# app is not reliably first or last. Match on argv[0], which only the app has.
#
# It also matters that the pattern lives in this file rather than on a caller's
# command line: `pkill -f` matches its own invocation's arguments, so a caller
# that mentions the process name while killing it kills its own shell.
#
# usage: apppid.sh [pid|kill]
NAME='HxPDS.exe'

pids() {
    for p in $(pgrep -f "$NAME" 2>/dev/null); do
        argv0=$(tr '\0' '\n' < "/proc/$p/cmdline" 2>/dev/null | head -1)
        case "$argv0" in
        *"$NAME") echo "$p" ;;
        esac
    done
}

case "${1:-pid}" in
pid)
    p=$(pids | head -1)
    [ -n "$p" ] || exit 1
    echo "$p"
    ;;
kill)
    p=$(pids)
    if [ -n "$p" ]; then
        # shellcheck disable=SC2086
        kill $p 2>/dev/null
        sleep 2
        p=$(pids)
        [ -n "$p" ] && kill -9 $p 2>/dev/null
        echo "killed"
    else
        echo "not running"
    fi
    ;;
*)
    sed -n '/^# usage:/p' "$0"; exit 1 ;;
esac
