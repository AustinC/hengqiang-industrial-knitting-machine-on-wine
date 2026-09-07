#!/bin/sh
# Swap wine's builtin msado15 (ADO) for MDAC 2.8's native one.
#
# After fixing oledb32, the app's next failure was "尚未实现" (E_NOTIMPL),
# traced to:
#     fixme:msado15:command_Execute ...
#     fixme:msado15:command_QueryInterface ... not implemented
# i.e. wine's builtin ADO has ADODB.Command.Execute as a stub, and this app
# drives its queries through ADODB.Command rather than Connection.Execute.
#
# This is the same override winetricks' load_native_mdac applies
# (w_override_dlls native,builtin msado15).
set -e
. "$(dirname "$0")/env.sh"
export LANG=C LC_ALL=C

CAB="$SRC/downloads/mdac_x/mdacxpak.cab"
STAGE="$SRC/downloads/mdac_x/native"
ADO_DIR="$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System/ado"

[ -f "$CAB" ] || { echo "!! missing $CAB"; exit 1; }

# wine created the dir as "ADO"; keep whichever casing already exists.
[ -d "$ADO_DIR" ] || ADO_DIR="$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System/ADO"
mkdir -p "$ADO_DIR"

echo "==> extracting native ADO set"
for f in msado15.dll msador15.dll msADOX.dll msadomd.dll msadrh15.dll msadco.dll msadcor.dll \
         msado20.tlb msado21.tlb msado25.tlb msado26.tlb msado27.tlb; do
    cabextract -q -d "$STAGE" -F "$f" "$CAB" >/dev/null 2>&1 || echo "   (skip $f)"
done

echo "==> backing up wine's stub msado15.dll"
[ -f "$ADO_DIR/msado15.dll.wine-builtin" ] || \
    cp -p "$ADO_DIR/msado15.dll" "$ADO_DIR/msado15.dll.wine-builtin" 2>/dev/null || true

echo "==> installing native ADO into $ADO_DIR"
for f in msado15.dll msador15.dll msADOX.dll msadomd.dll msadrh15.dll msadco.dll msadcor.dll \
         msado20.tlb msado21.tlb msado25.tlb msado26.tlb msado27.tlb; do
    [ -f "$STAGE/$f" ] && cp -p "$STAGE/$f" "$ADO_DIR/$f"
done

echo "==> setting native override for msado15"
wine reg add 'HKCU\Software\Wine\DllOverrides' /v msado15 /t REG_SZ /d "native,builtin" /f >/dev/null 2>&1
wineserver -w

echo "==> registering native ADO"
WIN_ADO='C:\Program Files (x86)\Common Files\System\ado'
for f in msado15.dll msador15.dll msADOX.dll msadomd.dll msadrh15.dll; do
    [ -f "$ADO_DIR/$f" ] && wine regsvr32 /s "$WIN_ADO\\$f" >/dev/null 2>&1 || true
done
wineserver -w

echo "==> verifying"
file "$ADO_DIR/msado15.dll" | sed 's/.*: //'
wine reg query 'HKLM\Software\Classes\Wow6432Node\CLSID\{00000514-0000-0010-8000-00AA006D2EA4}\InprocServer32' 2>/dev/null | grep -i REG_SZ
wine reg query 'HKCU\Software\Wine\DllOverrides' 2>/dev/null | grep -iE "msado15|oledb32|msdart|msdatl3"
