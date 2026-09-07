#!/bin/sh
# Register the ActiveX control the app ships but the installer never registered.
#
# The app hosts Flash10t.ocx in one of its MFC pages. With the control
# unregistered, MFC's OLE Control Container fails while loading the control's
# persisted state (WM_OCC_LOADFROMSTREAM), reads a bogus length, and calls
# malloc(0xFFFFFFFF) -- which fails and surfaces as the app's "内存不足"
# (out of memory) dialog on File > New.
#
# NOTE: LANG must be the Chinese locale here. regsvr32 is given a path
# containing Chinese characters, and under any other locale wine mis-decodes it
# and reports "Failed to load DLL".
set -e
. "$(dirname "$0")/env.sh"

APP_WIN='C:\Program Files (x86)\恒强\横机制板系统（16把纱嘴）'

for ocx in Flash10t.ocx; do
    echo "==> registering $ocx"
    wine regsvr32 /s "$APP_WIN\\$ocx" 2>&1 | grep -viE "fixme|^$" || true
done
wineserver -w

echo "==> verifying"
LANG=C wine reg query 'HKLM\Software\Classes\ShockwaveFlash.ShockwaveFlash\CLSID' 2>/dev/null \
    | grep -i REG_SZ || echo "   !! not registered"
