#!/bin/sh
# Read-only GUI observer: locate and screenshot wine windows.
# Input (clicks/typing) is done by hand, not from here.
#
# usage:
#   ui.sh find        -> list installer/app windows with geometry
#   ui.sh shot [name] -> screenshot the matching window to logs/ui.png
export DISPLAY="${DISPLAY:-:0}"
LOGDIR="${HQ_LOGDIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/logs}"
mkdir -p "$LOGDIR"

# Covers the InstallShield wizard and the app's own main window.
MATCH_DEFAULT='恒强|InstallShield|HxPDS|制版'

case "$1" in
find)
    xdotool search --name "." 2>/dev/null | while read -r w; do
        n=$(xdotool getwindowname "$w" 2>/dev/null) || continue
        [ -n "$n" ] || continue
        printf '%s\n' "$n" | grep -qE "$MATCH_DEFAULT" || continue
        printf '%s :: %s :: %s\n' "$w" "$n" \
            "$(xdotool getwindowgeometry --shell "$w" 2>/dev/null | grep -E 'WIDTH|HEIGHT' | tr '\n' ' ')"
    done
    ;;
shot)
    m="${2:-$MATCH_DEFAULT}"
    w=$(xdotool search --name "." 2>/dev/null | while read -r x; do
            n=$(xdotool getwindowname "$x" 2>/dev/null) || continue
            printf '%s\n' "$n" | grep -qE "$m" && echo "$x"
        done | tail -1)
    [ -z "$w" ] && { echo "no window matching: $m"; exit 1; }
    out="$LOGDIR/ui.png"
    import -window "$w" "$out" 2>/dev/null || { echo "capture failed for $w"; exit 1; }
    echo "$out  ($(identify -format '%wx%h' "$out" 2>/dev/null))  win=$w"
    echo "name: $(xdotool getwindowname "$w" 2>/dev/null)"
    ;;
*)
    sed -n '5,8p' "$0"
    ;;
esac
