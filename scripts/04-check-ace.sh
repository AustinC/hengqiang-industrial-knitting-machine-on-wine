#!/bin/sh
# Verify the ACE OLEDB provider is registered. This is the exact thing whose
# absence produced: err:oledb:get_data_source provider
# L"Microsoft.ACE.OLEDB.12.0" not registered
. "$(dirname "$0")/env.sh"

echo "--- ACE ProgID ---"
wine reg query 'HKLM\Software\Classes\Microsoft.ACE.OLEDB.12.0' /s 2>/dev/null | head -12 \
    || echo "NOT FOUND: Microsoft.ACE.OLEDB.12.0"

echo "--- ACEDAO / provider DLL on disk ---"
find "$WINEPREFIX/drive_c" -iname "ACEOLEDB.DLL" -o -iname "ACECORE.DLL" 2>/dev/null | head

echo "--- registered OLEDB providers ---"
wine reg query 'HKLM\Software\Classes' 2>/dev/null | grep -iE "ACE\.OLEDB|Jet\.OLEDB" | head
