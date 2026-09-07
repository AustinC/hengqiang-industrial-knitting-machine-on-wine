#!/bin/sh
# Report the prefix's ANSI/OEM codepage and locale. Expect ACP=936 for GBK.
. "$(dirname "$0")/env.sh"

echo "--- registry Nls\\CodePage ---"
wine reg query 'HKLM\System\CurrentControlSet\Control\Nls\CodePage' /v ACP 2>/dev/null | grep -i acp
wine reg query 'HKLM\System\CurrentControlSet\Control\Nls\CodePage' /v OEMCP 2>/dev/null | grep -i oemcp

echo "--- console codepage (chcp) ---"
wine cmd /c chcp 2>/dev/null | tr -d '\r'

echo "--- locale seen by wine ---"
wine cmd /c 'echo %LANG%' 2>/dev/null | tr -d '\r'
