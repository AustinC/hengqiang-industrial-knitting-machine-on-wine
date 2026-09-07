#!/bin/sh
# Install the Access 2007 Runtime, which supplies the Microsoft.ACE.OLEDB.12.0
# provider that HxPDS.exe needs to read its .accdb config/language databases.
set -e
. "$(dirname "$0")/env.sh"

echo "==> extracting AccessRuntime.exe"
rm -rf "$WINEPREFIX/drive_c/acert"
wine "$ACCESS_INSTALLER" /extract:'C:\acert' /quiet >"$LOGDIR/access-extract.log" 2>&1
wineserver -w

echo "==> installing AccessRT.msi silently"
# ACCEPT_EULA / DISPLAYEULA keep the Office 2007 installer from waiting on a
# license dialog that never renders under /qn.
wine msiexec /i 'C:\acert\AccessRT.msi' /qn /l*v 'C:\acert\install.log' \
    ACCEPT_EULA=1 DISPLAYEULA=0 ARPSYSTEMCOMPONENT=1 >"$LOGDIR/access-install.log" 2>&1 || {
        echo "!! msiexec returned $?; see $LOGDIR/access-install.log"
    }
wineserver -w

echo "==> checking for ACE OLEDB provider registration"
"$(dirname "$0")/04-check-ace.sh"
