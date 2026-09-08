#!/bin/sh
# Change the prefix's DPI in place, without rebuilding it.
#
# Wine renders at 96 DPI unless told otherwise, which on a 4K panel makes this
# app's menus and labels tiny. 01-rebuild-prefix.sh sets HQ_DPI at creation
# time; this changes it afterwards. The app reads it at startup, so restart it.
#
# 96 = 100%, 120 = 125%, 144 = 150%, 168 = 175%, 192 = 200%.
#
# usage: 26-set-dpi.sh [dpi]      (no argument: report the current value)
. "$(dirname "$0")/env.sh"

if [ -z "$1" ]; then
    cur=$(wine reg query 'HKCU\Control Panel\Desktop' /v LogPixels 2>/dev/null \
          | sed -n 's/.*REG_DWORD *0x\([0-9a-f]*\).*/\1/p')
    [ -n "$cur" ] && printf 'current DPI: %d (0x%s)\n' "0x$cur" "$cur" \
                  || echo "current DPI: unset (wine default, 96)"
    exit 0
fi

wine reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d "$1" /f >/dev/null 2>&1
wine reg add 'HKCU\Software\Wine\Fonts' /v LogPixels /t REG_DWORD /d "$1" /f >/dev/null 2>&1
echo "DPI set to $1 -- restart the app for it to take effect"
