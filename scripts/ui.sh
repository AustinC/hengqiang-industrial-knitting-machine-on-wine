#!/bin/sh
# GUI helper: find windows, screenshot them, and -- on a scratch display only --
# click and type.
#
# Two things are baked in, both learned the hard way:
#
#   * Screenshots grab the root window and crop to the target's geometry.
#     `import -window <id>` is broken in the ImageMagick build here (it exits
#     "missing an image filename" for every id, valid or not), and even a
#     working one cannot capture a window that another window covers: X has no
#     pixels to give for the hidden parts, so the grab fails with BadMatch.
#     Cropping the root sidesteps both, as long as nothing is on top -- which is
#     what 30-xvfb.sh is for.
#
#   * Input refuses to run on :0. Austin drives the real desktop; scripted
#     clicking belongs on the throwaway display. Override with HQ_ALLOW_INPUT=1
#     if you really mean it.
#
# usage:
#   ui.sh find [pattern]              list windows (id, name, geometry)
#   ui.sh shot <pattern|id> [out]     screenshot one window   -> logs/ui.png
#   ui.sh screen [out]                screenshot the display  -> logs/screen.png
#   ui.sh click <x> <y> <pattern|id>  click at window-relative x,y
#   ui.sh key <keys>                  send keys (xdotool syntax, e.g. Return)
#   ui.sh type <text>                 type text
#
# Pattern is an extended regex matched against the window name; the last match
# wins, which is normally the most recently mapped window (the dialog on top).
export DISPLAY="${DISPLAY:-:0}"
SRC=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LOGDIR="${HQ_LOGDIR:-$SRC/logs}"
mkdir -p "$LOGDIR"

# Covers the InstallShield wizard, the app's main window (it titles itself
# "HqPDS", not "HxPDS" like the binary) and its message boxes.
MATCH_DEFAULT='恒强|InstallShield|Hq?PDS|制版|制板|Hint|提示'

die() { echo "!! $*" >&2; exit 1; }

# Everything below wants "id name w h x y" for one window.
geom() {
    xdotool getwindowgeometry --shell "$1" 2>/dev/null
}

resolve() {
    # A bare number is already a window id.
    case "$1" in
    ''|*[!0-9]*) ;;
    *) echo "$1"; return 0 ;;
    esac
    m="${1:-$MATCH_DEFAULT}"
    w=$(xdotool search --name "." 2>/dev/null | while read -r x; do
            n=$(xdotool getwindowname "$x" 2>/dev/null) || continue
            printf '%s\n' "$n" | grep -qE "$m" && echo "$x"
        done | tail -1)
    [ -n "$w" ] || return 1
    echo "$w"
}

require_scratch_display() {
    [ "$HQ_ALLOW_INPUT" = 1 ] && return 0
    case "$DISPLAY" in
    :0|:0.0) die "refusing to send input to $DISPLAY -- start 30-xvfb.sh and
   export DISPLAY=:9, or set HQ_ALLOW_INPUT=1 to override" ;;
    esac
}

case "${1:-}" in
find)
    m="${2:-.}"
    xdotool search --name "." 2>/dev/null | while read -r w; do
        n=$(xdotool getwindowname "$w" 2>/dev/null)
        eval "$(geom "$w")" 2>/dev/null || continue
        # Wine litters the display with 1x1 helper windows; they are never what
        # anyone is looking for.
        [ "${WIDTH:-0}" -lt 40 ] && continue
        [ "${HEIGHT:-0}" -lt 20 ] && continue
        printf '%s\n' "${n}" | grep -qE "$m" || continue
        printf '%-10s %5sx%-5s @%5s,%-5s  %s\n' "$w" "$WIDTH" "$HEIGHT" "$X" "$Y" "$n"
    done
    ;;

shot)
    w=$(resolve "${2:-}") || die "no window matching: ${2:-$MATCH_DEFAULT}"
    out="${3:-$LOGDIR/ui.png}"
    eval "$(geom "$w")" || die "no geometry for $w"
    tmp=$(mktemp -t hqshot.XXXXXX.png)
    import -window root "$tmp" || die "root capture failed on $DISPLAY"
    # +repage drops the crop offset, so the result is a plain image again.
    magick "$tmp" -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" +repage "$out" \
        || die "crop failed"
    rm -f "$tmp"
    echo "$out  ($(identify -format '%wx%h' "$out"))  win=$w"
    echo "name: $(xdotool getwindowname "$w" 2>/dev/null)"
    ;;

screen)
    out="${2:-$LOGDIR/screen.png}"
    import -window root "$out" || die "root capture failed on $DISPLAY"
    echo "$out  ($(identify -format '%wx%h' "$out"))  display=$DISPLAY"
    ;;

click)
    require_scratch_display
    [ $# -ge 3 ] || die "usage: ui.sh click <x> <y> [pattern|id]"
    rx=$2; ry=$3
    w=$(resolve "${4:-}") || die "no window matching: ${4:-$MATCH_DEFAULT}"
    eval "$(geom "$w")" || die "no geometry for $w"
    xdotool windowactivate --sync "$w" 2>/dev/null
    xdotool mousemove --sync $((X + rx)) $((Y + ry)) click 1
    echo "clicked $((X + rx)),$((Y + ry)) (window $w + $rx,$ry)"
    ;;

key)
    require_scratch_display
    shift
    [ $# -ge 1 ] || die "usage: ui.sh key <keys>"
    xdotool key --clearmodifiers "$@"
    echo "sent keys: $*"
    ;;

type)
    require_scratch_display
    shift
    [ $# -ge 1 ] || die "usage: ui.sh type <text>"
    xdotool type --clearmodifiers -- "$*"
    echo "typed: $*"
    ;;

*)
    sed -n '/^# usage:/,/^# Pattern/p' "$0"
    ;;
esac
