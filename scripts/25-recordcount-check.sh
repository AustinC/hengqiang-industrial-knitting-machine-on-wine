#!/bin/sh
# Check what Recordset.RecordCount reports for the app's own database.
#
# This is the one-line test for the bug behind both document blockers: stock
# wine answers -1 for every query, because it only implements RecordCount for
# providers exposing IRowsetExactScroll and ACE does not. With
# patches/0003 applied the counts are real. Run it before and after
# 18-install-patched-msado15-system.sh to see the difference.
#
# The database password is the vendor's and is deliberately not stored in this
# repo, so it is lifted from a trace log at run time and written only to a
# temporary script inside the prefix, which is removed again on exit.
set -e
. "$(dirname "$0")/env.sh"

APPDIR="$WINEPREFIX/drive_c/Program Files (x86)/恒强/横机制板系统（16把纱嘴）"
DB="$APPDIR/HengJi.accdb"
[ -f "$DB" ] || { echo "!! database not found: $DB"; exit 1; }

# connection_Open logs the whole connection string, password included.
# -m1 is per file, so head -1 is what actually keeps this to a single line.
PW=$(grep -h 'connection_Open.*HengJi.accdb' "$LOGDIR"/*.log 2>/dev/null \
     | head -1 | sed 's/.*Database Password=//; s/;".*//')
[ -n "$PW" ] || {
    echo "!! no connection string in $LOGDIR/*.log"
    echo "   run scripts/09-run-trace.sh once first -- it logs connection_Open"
    exit 1
}

# ACE is given an ASCII path: this is about RecordCount, and a copy keeps the
# Chinese-path and cscript-encoding questions out of the result.
WORK="$WINEPREFIX/drive_c/rccheck.accdb"
VBS="$WINEPREFIX/drive_c/rccheck.vbs"
trap 'rm -f "$WORK" "$VBS"' EXIT
cp "$DB" "$WORK"

cat >"$VBS" <<VBSEOF
Dim conn, cmd
Set conn = CreateObject("ADODB.Connection")
conn.Open "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\rccheck.accdb;Jet OLEDB:Database Password=$PW;"
' The app uses a client-side cursor, which is what makes RecordCount meaningful.
conn.CursorLocation = 3
Set cmd = CreateObject("ADODB.Command")
Set cmd.ActiveConnection = conn

Sub Try(label, sql)
  Dim rs
  On Error Resume Next
  cmd.CommandText = sql
  Set rs = cmd.Execute
  If Err.Number <> 0 Then
    WScript.Echo label & ": FAILED 0x" & Hex(Err.Number) & " " & Err.Description
    Err.Clear
    Exit Sub
  End If
  ' MoveLast first: the idiom the app itself uses to make the count valid.
  rs.MoveLast
  Err.Clear
  WScript.Echo label & ": RecordCount = " & rs.RecordCount
  rs.Close
  On Error Goto 0
End Sub

Try "Factory                ", "SELECT * FROM Factory"
Try "machine                ", "SELECT * FROM machine"
Try "FuncLineAndType        ", "SELECT * FROM FuncLineAndType WHERE MachineId = 0"
Try "FuncLineAndType (UNION)", "SELECT * FROM (SELECT * FROM FuncLineAndType WHERE MachineId = 0 AND MenuTypeId = 0 UNION SELECT * FROM FuncLineAndType WHERE MachineId = 0 AND MenuTypeId = 0 AND MenuTypeGroup NOT IN (SELECT MenuTypeGroup FROM FuncLineAndType WHERE MachineId = 0 AND MenuTypeId = 0)) AS AA ORDER BY TypeId, ID"
conn.Close
VBSEOF

echo "-1 everywhere means patches/0003 is not in effect."
echo
# 32-bit cscript: the app is 32-bit and ACE is registered under Wow6432Node.
wine C:\\windows\\syswow64\\cscript.exe //nologo C:\\rccheck.vbs 2>/dev/null \
    | iconv -f gbk -t utf-8 2>/dev/null || true
