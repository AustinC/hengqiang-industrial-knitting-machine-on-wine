#!/bin/sh
# Open every shipped sample document in turn and record which ones crash.
#
# The point is blast radius: if only documents saved by an older version fall
# over, the app is usable today and the crash is in a legacy-format path; if
# every document crashes, it is on the critical path and has to be fixed.
#
# usage: 24-survey-docs.sh [dir]     (default: the shipped pds_file samples)
SRC=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$SRC/scripts/env.sh"

DIR="${1:-$WINEPREFIX/drive_c/Program Files (x86)/恒强/横机制板系统（16把纱嘴）/pds_file}"
OUT="$LOGDIR/survey.txt"
: >"$OUT"

for doc in "$DIR"/*.[pP][dD][sS]; do
    [ -f "$doc" ] || continue
    name=$(basename "$doc")
    printf '%-44s ' "$name"
    result=$(WINEDEBUG=+seh "$SRC/scripts/23-repro-open.sh" "$doc" survey 2>&1)
    if printf '%s' "$result" | grep -q "CRASHED"; then
        addr=$(printf '%s' "$result" | grep -o "at address [0-9A-Fa-f]*" | head -1)
        verdict="CRASH  ${addr:-?}"
    elif printf '%s' "$result" | grep -q "no prompt"; then
        verdict="ok     (current format, no prompt)"
    else
        verdict="ok     (older format, confirmed)"
    fi
    printf '%s\n' "$verdict"
    printf '%-44s %s\n' "$name" "$verdict" >>"$OUT"
done

echo
echo "written to $OUT"
