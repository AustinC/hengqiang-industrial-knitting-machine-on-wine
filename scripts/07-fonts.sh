#!/bin/sh
# CJK font coverage for the prefix.
#
# Separate concern from the codepage: the codepage decides which *characters*
# the bytes mean, fonts decide whether those characters can be *drawn*. Without
# these you get tofu boxes even with ACP=936 correct.
#
# LANG is deliberately forced to C here so winetricks' own messages stay in
# English -- only the app itself needs the Chinese locale.
set -e
. "$(dirname "$0")/env.sh"
export LANG=C LC_ALL=C

echo "==> fakechinese (aliases SimSun/SimHei/MS YaHei -> Source Han Sans)"
winetricks -q fakechinese >"$LOGDIR/fonts-fakechinese.log" 2>&1 || echo "(fakechinese exit $?)"

echo "==> wenquanyizenhei (real CJK font, extra glyph coverage)"
winetricks -q wenquanyizenhei >"$LOGDIR/fonts-wqy.log" 2>&1 || echo "(wqy exit $?)"

wineserver -w

echo "==> installed font files:"
ls "$WINEPREFIX/drive_c/windows/Fonts" 2>/dev/null | head -20

echo "==> font substitutions:"
wine reg query 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes' 2>/dev/null | head -20
