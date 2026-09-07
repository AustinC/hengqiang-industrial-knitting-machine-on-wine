#!/bin/sh
# Return the prefix to the furthest-working configuration.
#
# Keep : native oledb32 + msdart + msdatl3  (verified fix -- makes
#        "Jet OLEDB:Database Password" reach ACE, so the .accdb files open)
# Drop : native msado15 and the rest of the MDAC set (regression -- native ADO
#        demands CLSID {6c736db1-bd94-11d0-8a23-00aa00b58e10}, which exists
#        nowhere in MDAC 2.8 nor anywhere else on this system, and the app dies
#        silently instead of merely erroring)
set -e
. "$(dirname "$0")/env.sh"
export LANG=C LC_ALL=C

CF="$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System"

echo "==> removing native overrides except the oledb32 trio"
for d in msado15 msadce msadds msdaps msdasc msdaenum msdaprst; do
    wine reg delete 'HKCU\Software\Wine\DllOverrides' /v "$d" /f >/dev/null 2>&1 || true
done

echo "==> restoring wine builtins (keeping native oledb32)"
find "$CF" -name "*.dll.wine-builtin" 2>/dev/null | while read -r bak; do
    orig="${bak%.wine-builtin}"
    case "$(basename "$orig")" in
        oledb32.dll) echo "   keep native: $(basename "$orig")"; continue ;;
    esac
    cp -p "$bak" "$orig" && echo "   restored: $(basename "$orig")"
done

echo "==> re-registering builtin ADO"
wine regsvr32 /s 'C:\windows\syswow64\msado15.dll' >/dev/null 2>&1 || true
wineserver -w

echo "==> final overrides:"
wine reg query 'HKCU\Software\Wine\DllOverrides' 2>/dev/null | grep REG_SZ || echo "(none)"
