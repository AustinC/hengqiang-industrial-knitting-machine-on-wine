#!/bin/sh
# Shared environment for the HQ-PDS16 wine scripts. Sourced, not executed.
#
# Everything here can be overridden from the environment, e.g.
#     WINEPREFIX=~/.wine-hqpds HQ_DPI=192 ./scripts/01-rebuild-prefix.sh

# Repo root, derived from this file's location -- no fixed install path.
SRC=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# Dedicated prefix by default so this app can't disturb an existing ~/.wine.
# Override with WINEPREFIX if you want to reuse one.
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine-hqpds}"

# Needed because wine talks to an X server; adjust if yours isn't :0.
export DISPLAY="${DISPLAY:-:0}"

# zh_CN.UTF-8 gives wine ANSI codepage 936 (GBK), which the installer needs so
# its Chinese path and resource names decode correctly instead of turning into
# \x7f\x7f mojibake. Applied per-process on purpose: exporting it globally
# would also translate wine's own tools (winecfg, winetricks) into Chinese.
export LANG=zh_CN.UTF-8

# Wine defaults to 96 DPI. On a HiDPI panel the app renders microscopically.
# 96 = 100%, 120 = 125%, 144 = 150%, 168 = 175%, 192 = 200%. Pick to taste.
#
# 144 suits a 4K 27-31" panel (~140 real DPI), which is what this was developed
# on. The app scales cleanly -- menus, dialogs and toolbars all follow -- though
# BCGControlBar's toolbar bitmaps are upscaled, so they soften above ~150%.
# Use 26-set-dpi.sh to change it on an existing prefix.
DPI="${HQ_DPI:-144}"

# Vendor installers. Put them in the repo root, or point these at wherever you
# keep them. Neither can be redistributed here, so you must supply your own.
APP_INSTALLER="${HQ_APP_INSTALLER:-$SRC/HQ-PDS16(980).exe}"
ACCESS_INSTALLER="${HQ_ACCESS_INSTALLER:-$SRC/AccessRuntime.exe}"

LOGDIR="${HQ_LOGDIR:-$SRC/logs}"
mkdir -p "$LOGDIR"

# Optional wine virtual desktop, e.g. HQ_VDESKTOP=1920x1200. Worth switching on
# for the headless display from 30-xvfb.sh: there is no window manager there, so
# without it nothing stacks or takes focus, and the app's modal dialogs end up
# unreachable. Wine's own desktop window does that job itself.
VDESKTOP="${HQ_VDESKTOP:-}"

# Launch a windows binary, honouring HQ_VDESKTOP. Use in place of bare `wine`.
hq_wine() {
    if [ -n "$VDESKTOP" ]; then
        wine explorer /desktop=hqpds,"$VDESKTOP" "$@"
    else
        wine "$@"
    fi
}
