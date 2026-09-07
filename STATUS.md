# HQ-PDS16 (恒强 980) under Wine — status

**Software:** 恒强新一代制版系统（16把纱嘴） / HQ-PDS16 — Hengqiang flat-knitting
CNC pattern-design software, 2020, 32-bit MFC + BCGControlBar, Access `.accdb`
data store via ADO/OLE DB.

**Verdict as of 2026-09-07: RUNS, DOCUMENTS DO NOT.** The app installs,
launches, and reaches its full pattern-design UI with a clean startup log and
correct Chinese throughout. Getting there needed four prefix-level fixes, a
missing Jet component, and **four patches to Wine's `msado15` (ADO)** in
`patches/`.

Still broken: **opening or creating a document.** `File > Open` crashes;
`File > New` reports 内存不足 ("out of memory"). Both are traced to the same
area -- see [Open blockers](#open-blockers). The database layer itself is fully
working and independently stress-verified.

---

## What works (all verified, not assumed)

| Area | Detail |
|---|---|
| Install | Completes to `C:\Program Files (x86)\恒强\横机制板系统（16把纱嘴）\`, 64 files, correct Chinese path |
| Locale / codepage | `ACP=936` (GBK) — Chinese paths and UI strings decode correctly |
| Fonts | Source Han Sans + WenQuanYi; `SimSun`/`SimHei`/`Microsoft YaHei`/`KaiTi` aliased. No tofu anywhere |
| HiDPI | 144 DPI (panel is 3840x2160 @ 698mm ≈ 140 DPI; Wine defaults to 96) |
| ACE OLE DB provider | `Microsoft.ACE.OLEDB.12.0` registered and loading |
| VC++ runtime | 2015 x86 redist installed; `mfc140u.dll` present (needed by `BCGCBPRO2510u140.dll`) |
| ODBC | `unixodbc` installed, `libodbc.so.2` error gone |
| Database access | `.accdb` files open successfully, password and all |
| **Application UI** | **Full pattern-design UI loads** — menus, drawing-tool palette, canvas, colour panel |

## Wine patches (in `patches/`)

The app was blocked by two `E_NOTIMPL` stubs in Wine's ADO implementation. Both
surfaced as the same useless dialog, **尚未实现。** ("not yet implemented").

### `0001-msado15-implement-command_Execute.patch`

`ADODB.Command.Execute` was a bare stub. The app runs real SQL through it —
traced as `SELECT * FROM LanguageMap` with `adCmdText`.

The fix is small because `get_rowset()` in `recordset.c` *already* has an
`ICommandText` fallback: it tries the source as a table name first, then
executes it as a command. So `command_Execute` just mirrors the existing
`connection_Execute` and delegates to `_Recordset_Open`, passing
`adOpenForwardOnly, adLockReadOnly` — which both matches real ADO's
`Command.Execute` default and requests the fewest rowset capabilities from the
provider. It logs a FIXME if parameters are ever passed, so silently wrong
results can't happen unnoticed.

### `0002-msado15-implement-recordset-Collect.patch`

With `Execute` working the app opened the recordset and began iterating
(`MoveFirst`, `get_BOF`, `get_EOF` all fine) then hit
`recordset_get_Collect`. `Collect` is the property behind the recordset's
default member — `rs("Base")` in the app's case. Wine already implemented
`Fields.Item()` (including lookup by name) and `Field.Value`, so `Collect` is
just shorthand over those. Implemented both getter and setter that way.

Both are worth sending upstream to WineHQ. Neither is app-specific.

### Applying them

```sh
scripts/20-build-msado15.sh                       # fetch source, patch, build
sudo scripts/18-install-patched-msado15-system.sh # install (or 'revert')
```

Wine only ever loads a builtin DLL from its own install dir, so the patched
`msado15.dll` has to replace `/usr/lib/wine/i386-windows/msado15.dll`. Two
no-sudo routes were tried and both fail: a `native` DllOverride is *refused*
because the build is a wine-builtin PE, and `WINEDLLPATH` is ignored for PE
builtins. The stock DLL is backed up beside it as `.stock`, and a wine package
upgrade will overwrite the patch, so re-run after upgrading.

## Open blockers

Two symptoms, almost certainly one cause.

### `File > New` -> 内存不足 ("out of memory")

Not memory at all. Relay tracing caught the exact call:

```
Call KERNEL32.FindResourceW(00400000, 00000bb9, 00000005)   RT_DIALOG id 3001, in HxPDS.exe
Ret  KERNEL32.FindResourceW() retval=00000000               NOT FOUND
...
Call ucrtbase.malloc(ffffffff)   ret=78ebc9b1 (mfc140u+0x4C9B1)
Ret  ucrtbase.malloc() retval=00000000
```

MFC fails to find dialog template 3001, gets a NULL template, computes a length
of -1 from it, and asks for 4 GB. The allocation fails and MFC raises its
out-of-memory error.

Parsing the PE resources directly proves dialog 3001 is **genuinely absent**
from `HxPDS.exe` (it has 64 dialogs, none of them 3001), so this is not a Wine
resource-lookup bug. Dialog 3001 lives in **`HengJi.dll`** (141 dialogs) -- the
machine-specific MFC extension DLL, matching `DllName = "Hengji"` in the
`machine` table row the app selects (ID 100005, "H2-2").

`HengJi.dll` *does* load successfully (seen at 0x726B0000 in a `+loaddll`
trace), and all its imports resolve. The key observation is that the failing
lookup queries **only** the app's own module handle (0x00400000) and never
`HengJi.dll`'s -- so the DLL is loaded but its resources are not in MFC's
search chain (`CDynLinkLibrary` list) at that point.

### `File > Open` -> crash

```
Unhandled page fault on write access to 07E5601C at address 1001D189
```

`BaseMachine.dll + 0x1D189` writing through a wild pointer. The target address
differed between runs (`0x0863002C` vs `0x07E5601C`), so the pointer is garbage
rather than a fixed miscalculation. In one run the target landed inside
`XCPTHLR.dll`'s mapped image at offset 0x2C -- PE header territory, read-only,
hence the fault.

### Leading hypothesis

`BaseMachine.dll` imports `HengJi.dll`, and `HengJi.dll` owns the missing
dialog. If the app's machine-plugin handshake with `HengJi.dll` fails -- its
extension-module init not registering a `CDynLinkLibrary`, or a factory call
returning NULL that nobody checks -- then both symptoms follow from one cause:
MFC cannot see HengJi's resources (missing dialog -> malloc(-1)), and
`BaseMachine` operates on a null/garbage machine object (wild write).

Next step would be to inspect `HengJi.dll`'s exports and `DllMain`, and trace
the `BaseMachine` -> `HengJi` calls to find the first one that fails.

### Diagnostic notes for whoever picks this up

* The app installs its own crash handler (`XCPTHLR.dll`) that enumerates
  symbols across all 97 modules. It emits **millions** of relay lines *after*
  the fault, burying it. Budget for that when tracing.
* `winedbg` gives no usable 32-bit stack under WoW64, and its console window
  will not accept keyboard input. The useful backtrace came from Wine's own
  crash dialog (详细信息 / Details), which prints the module map -- enough to
  map a fault address to a module by hand.
* `ptrace_scope` must be 0 for Wine's crash handler to attach at all:
  `sudo sysctl -w kernel.yama.ptrace_scope=0`.
* Relay tracing is only tractable with filters. `RelayInclude` limited to a
  handful of APIs (allocation, file I/O, resources) plus `RelayFromInclude`
  limited to the app's own DLLs is what made the malloc(-1) findable.
* MFC funnels every allocation through one wrapper (`mfc140u+0x4C9B1` here), so
  relay shows the size but never the code that computed it.

## Root causes found and fixed

Four independent bugs stacked on top of each other. Each was mistaken for the
previous one until isolated.

### 1. Mojibake install paths (`\x7f\x7f` instead of `恒强`)

No Chinese locale existed on the system, so Wine fell back to codepage 1252 and
the installer's GBK path bytes were misdecoded. Fixed by generating
`zh_CN.UTF-8` and creating the prefix under it, giving `ACP=936`.

Note: `LANG` also translates Wine's *own* UI, so it is applied **only** to the
app process, never to `winecfg`/`winetricks` — see `scripts/env.sh`.

Also note the installer has its own language-selection dialog; picking
`中文 (简体)` makes it apply `TRANSFORMS=...\2052.MST` (2052 = zh-CN LCID).

### 2. Tofu glyphs

Separate concern from the codepage: the codepage decides what the bytes *mean*,
fonts decide whether those characters can be *drawn*. `winetricks fakechinese`
writes aliases to `HKCU\Software\Wine\Fonts\Replacements` (Wine's own key — not
Windows' `FontSubstitutes`).

### 3. `Microsoft.ACE.OLEDB.12.0 not registered`

Access 2007 Runtime installed fine, and wrote the CLSID key
`{3BE786A0-0366-4F5C-9434-25CF162E475E}` — but **without an `InprocServer32`
subkey**, so COM had no DLL to load. MSI class registration doesn't complete
under Wine. Fixed with `regsvr32 ACEOLEDB.DLL`.

Gotcha: the app is 32-bit, so this lives under `Wow6432Node`. A 64-bit
`wine cscript` test will report "not registered" even when it is — use
`C:\windows\syswow64\cscript.exe`.

### 4. `调用失败` / `0x80004005` — the interesting one

Wine's builtin `oledb32` (which implements `MSDAINITIALIZE`, the
connection-string parser) silently fails on **provider-specific** keywords. The
app connects with:

```
Provider=Microsoft.ACE.OLEDB.12.0;Data Source=...\language.accdb;Jet OLEDB:Database Password=<REDACTED>;
```

Isolated with `C:\dbtest3.vbs`, which made the diagnosis unambiguous:

| Connection string | builtin oledb32 | native oledb32 |
|---|---|---|
| bare | `0x80040E4D` "Not a valid password" | `0x80040E4D` |
| **+ correct password** | `0x80004005` | **`OPEN OK`** |
| + **wrong** password | `0x80004005` — *identical to correct* | `0x80040E4D` |
| + unrelated `Jet OLEDB:Engine Type` | `0x80004005` | `0x80040E4D` |

A wrong password failing *identically* to the right one proved the password was
never reaching ACE. Fixed with native `oledb32.dll` + `oledb32r.dll` +
`msdatl3.dll` + `msdart.dll` from MDAC 2.8, dropped into
`Common Files\System\OLE DB\` (where `MSDAINITIALIZE` is already registered;
Wine's file there is a stub PE forwarding to its builtin `.so`).

---

## Dead ends (don't retry these)

- **`winetricks mdac28` / `nt40`** — refuse on any win64 prefix.
- **`WINEARCH=win32` prefix** — impossible: Arch's Wine is WoW64-only
  (`WINEARCH is set to 'win32' but this is not supported in wow64 mode`).
  Multilib is disabled and not needed by this Wine build.
- **Native MDAC 2.8 `msado15` (to get `Command.Execute`)** — a regression, not a
  fix. Native ADO demands CLSID `{6c736db1-bd94-11d0-8a23-00aa00b58e10}` when
  `ADODB.Connection` is created. That GUID appears in **no** cab and **no** `.inf`
  in MDAC 2.8, and in nothing else installed on this system (searched the whole
  prefix and `/usr/lib/wine` for its binary little-endian form). With it in
  place the app dies silently instead of showing an error. Installing the full
  MDAC set (cursor engine, `msdaps`, `msdasc`, `msdaenum`, `msdaprst`, RDS)
  did not satisfy it either.
- **Registering `Flash10t.ocx`** — the app ships this ActiveX control and the
  installer never registers it, so registering it looked promising. It did
  **not** fix 内存不足. `scripts/21-register-app-ocx.sh` still does it, and the
  nearby `WM_OCC_LOADFROMSTREAM` message that suggested it turned out to occur
  *after* the failing allocation, not before. Flash is end-of-life; unregister
  it if you would rather not keep it (`regsvr32 /u`).
- **`HQ-PDS16(980).exe /extract_all:`** — InstallShield error 1152.
- **InstallShield record mode (`/r /f1`)** — produces no `setup.iss` here, so the
  GUI install cannot be replayed silently.

## Untested unknowns

- **SoftDog USB dongle.** The package ships `SoftDogSetup.dll` /
  `SoftDogInstdrv.exe` and an "Install SoftDog" shortcut. It was deliberately
  skipped. Wine cannot load Windows kernel-mode drivers, so if the app requires
  the physical dongle there is a second wall behind the current one.
- **Wine's ADO `Recordset` support** may be similarly thin even if
  `Command.Execute` were implemented.
- `MSXML 4.0` and SOAP Toolkit 3.0 are unregistered (Wine ships MSXML 3/6 only),
  but a COM trace showed the app requests neither at startup.

---

## Options from here

1. **Windows VM (QEMU/KVM)** — most reliable path to actually using the software,
   and USB passthrough covers the dongle if it turns out to be required.
   *This is the chosen direction.*
2. **Patch Wine** — implement `command_Execute` in `dlls/msado15/command.c`
   (delegate to the OLE DB command; `Connection.Open` already works here), build,
   and drop the patched `msado15.dll` into the prefix with a native override.
   The correct engineering fix, and worth reporting upstream regardless.
3. Leave as-is; the prefix is in its furthest-working state.

---

## Reference

- Vendor: Zhejiang Hengqiang Technology Co., Ltd. — download centre at
  <https://www.hqcnc.com/download.html>, where this is listed as "Hengqiang 980
  Plate Making Software" (~214 MB, matching `HQ-PDS16(980).exe` at 224,599,559
  bytes). An English manual is published alongside it, which is likely the best
  reference for what the app's dialogs and machine parameters actually mean.
- App: `C:\Program Files (x86)\恒强\横机制板系统（16把纱嘴）\HxPDS.exe`
- Databases: `language.accdb` (UI strings), `HengJi.accdb` (37 MB) — encrypted,
  format `Standard ACE DB`. The password is the vendor's, hardcoded in the app;
  it is deliberately not recorded here. Recover it from your own copy if you
  need it for diagnostics: run `scripts/09-run-trace.sh` and grep the log for
  `connection_Open`, which logs the full connection string.
- App's own logs (`all_msgs.log` etc., log4cplus) stay 0 bytes — it fails before
  logging, so Wine-side tracing is the only useful signal
- Prefix: `~/.wine`, WoW64, `ACP=936`, 144 DPI, win10 (`CurrentVersion` 6.3 /
  build 19045 after the MDAC winver churn)

### Scripts (`scripts/`)

Run in order for a clean rebuild. Only step 05 needs mouse/keyboard.

| Script | Purpose |
|---|---|
| `env.sh` | Shared config — prefix, `LANG=zh_CN.UTF-8`, DPI, paths |
| `01-rebuild-prefix.sh` | Nuke + recreate prefix with Chinese locale and HiDPI |
| `02-check-codepage.sh` | Assert `ACP=936` |
| `03-install-access.sh` | Access 2007 Runtime, silent, + ACE check |
| `04-check-ace.sh` | Verify ACE provider registration |
| `05-install-app-record.sh` | App install (**GUI — needs clicking**) |
| `06-install-app-silent.sh` | Silent replay — *non-functional, no `setup.iss`* |
| `07-fonts.sh` | CJK fonts + aliases |
| `08-run.sh` | Launch the app, log to `logs/run.log` |
| `09-run-trace.sh` | Launch with `WINEDEBUG=+msado15,+oledb,+msi` |
| `10-fix-oledb.sh` | Attempt `winetricks mdac28` — *fails on win64, kept for the record* |
| `11-install-mdac.sh` | MDAC via its own installer — *fails, OS check* |
| `12-native-oledb32.sh` | **The real fix** — native `oledb32`/`msdatl3`/`msdart` |
| `13-native-ado.sh` | Native ADO — *regression, do not run* |
| `14-revert-native-ado.sh` | Undo 13 |
| `15-full-native-mdac.sh` | Full native MDAC set — *did not help* |
| `16-restore-best-state.sh` | Return to furthest-working config |
| `17-install-patched-msado15.sh` | Drop patched DLL in prefix — *insufficient, see 18* |
| `18-install-patched-msado15-system.sh` | **Install patched msado15 (needs sudo)** |
| `19-install-jet-expression-service.sh` | **vbajet32 + expsrv — fixes `#3092`** |
| `20-build-msado15.sh` | Fetch wine source, apply patches, build |
| `21-register-app-ocx.sh` | Register `Flash10t.ocx` — *did not fix anything* |
| `ui.sh` | Read-only helper: locate + screenshot Wine windows |

After a rebuild, re-apply `12-native-oledb32.sh` (needs
`downloads/MDAC_TYP.EXE`, sha256
`157ebae46932cb9047b58aa849ac1885e8cbd2f218810cb83e57613b49c679d6`, extracted to
`downloads/mdac_x/`).

Test harnesses live in the prefix root: `C:\dbtest.vbs`, `dbtest2.vbs`
(ASCII vs Chinese path A/B), `dbtest3.vbs` (keyword isolation). Run them with
the **32-bit** cscript.
