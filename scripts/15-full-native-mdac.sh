#!/bin/sh
# Last attempt at native ADO: install the *rest* of MDAC 2.8's data-access
# components, not just msado15 + oledb32.
#
# 13-native-ado.sh failed because native msado15 wants CLSID
# {6c736db1-bd94-11d0-8a23-00aa00b58e10} when ADODB.Connection is created.
# That GUID isn't findable in the package, but the components most likely to
# self-register it (the client cursor engine, the OLE DB service components,
# the proxy/stub DLL) were never installed. Install and register the whole set,
# then re-enable native ADO and see if creation succeeds.
set -e
. "$(dirname "$0")/env.sh"
export LANG=C LC_ALL=C

CAB="$SRC/downloads/mdac_x/mdacxpak.cab"
STAGE="$SRC/downloads/mdac_x/allcabs"      # already fully extracted earlier
CF="$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System"

WIN_CF='C:\Program Files (x86)\Common Files\System'

[ -d "$STAGE" ] || { echo "!! missing $STAGE"; exit 1; }

# Conventional MDAC layout: OLE DB service components, the RDS/cursor set in
# msadc, and ADO proper in ado.
OLEDB_SET="msdaps.dll msdasc.dll msdaenum.dll msdaprst.dll msdaprsr.dll msdaer.dll
           msdadc.dll msdatt.dll msdaurl.dll msxactps.dll msdarem.dll msdaremr.dll
           msdasql.dll msdasqlr.dll oledb32a.dll"
MSADC_SET="msadce.dll msadcer.dll msadds.dll msaddsr.dll msadco.dll msadcor.dll
           msadcf.dll msadcfr.dll msadcs.dll msdfmap.dll"
ADO_SET="msado15.dll msador15.dll msADOX.dll msadomd.dll msadrh15.dll msader15.dll msjro.dll"

mkdir -p "$CF/msadc"
ADO_DIR="$CF/ADO"; [ -d "$ADO_DIR" ] || ADO_DIR="$CF/ado"
OLEDB_DIR="$CF/OLE DB"

install_set() {
    dir="$1"; shift
    for f in $*; do
        if [ -f "$STAGE/$f" ]; then
            # Don't clobber wine's stub without keeping a copy.
            [ -f "$dir/$f" ] && [ ! -f "$dir/$f.wine-builtin" ] && \
                cp -p "$dir/$f" "$dir/$f.wine-builtin" 2>/dev/null || true
            cp -p "$STAGE/$f" "$dir/$f"
        fi
    done
}

echo "==> installing OLE DB service components"
install_set "$OLEDB_DIR" $OLEDB_SET
echo "==> installing cursor engine / RDS set"
install_set "$CF/msadc" $MSADC_SET
echo "==> installing ADO set"
install_set "$ADO_DIR" $ADO_SET

echo "==> msdart to syswow64 (already there, refresh)"
[ -f "$STAGE/msdart.dll" ] && cp -p "$STAGE/msdart.dll" "$WINEPREFIX/drive_c/windows/syswow64/msdart.dll"

echo "==> native overrides"
for d in msado15 msadce msadds msdaps msdasc msdaenum msdaprst; do
    wine reg add 'HKCU\Software\Wine\DllOverrides' /v "$d" /t REG_SZ /d "native,builtin" /f >/dev/null 2>&1
done
wineserver -w

echo "==> registering everything (failures are expected for some)"
reg_dir() {
    win="$1"; dir="$2"; shift 2
    for f in $*; do
        [ -f "$dir/$f" ] || continue
        wine regsvr32 /s "$win\\$f" >/dev/null 2>&1 && echo "   ok   $f" || echo "   FAIL $f"
    done
}
reg_dir "$WIN_CF\\OLE DB" "$OLEDB_DIR" $OLEDB_SET
reg_dir "$WIN_CF\\msadc"  "$CF/msadc"  $MSADC_SET
reg_dir "$WIN_CF\\ADO"    "$ADO_DIR"   $ADO_SET
wineserver -w

echo "==> target CLSID registered now?"
wine reg query 'HKLM\Software\Classes\Wow6432Node\CLSID\{6C736DB1-BD94-11D0-8A23-00AA00B58E10}' /s 2>/dev/null | head -5 \
    || echo "   still NOT registered"
