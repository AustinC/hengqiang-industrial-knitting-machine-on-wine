# HQ-PDS16 (恒强 980) under Wine — status

**Software:** 恒强新一代制版系统（16把纱嘴） / HQ-PDS16 — Hengqiang flat-knitting
CNC pattern-design software, 2020, 32-bit MFC + BCGControlBar, Access `.accdb`
data store via ADO/OLE DB.

**Verdict as of 2026-09-07: RUNS, AND DOCUMENTS WORK.** The app installs,
launches, reaches its full pattern-design UI with correct Chinese throughout,
opens `.pds` documents — all 26 shipped samples, verified unattended by
`scripts/24-survey-docs.sh` — and creates new ones through its machine-model
and canvas-size wizard. Getting there needed four prefix-level fixes, a missing
Jet component, and **five patches to Wine's `msado15` (ADO)** in `patches/`.

The two long-standing blockers, `File > Open` crashing and `File > New`
reporting 内存不足, turned out to be one bug with two faces, and not where the
symptoms pointed: Wine's `Recordset.RecordCount` returned -1 for every query.
See [root cause 7](#7-recordcount-always--1--the-document-crashes) and the
[walkthrough](#how-the-file--open-crash-was-tracked-down).

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
| Application UI | Full pattern-design UI loads — menus, drawing-tool palette, canvas, colour panel |
| **`File > Open`** | **Works.** All 26 shipped samples; pattern renders, view tabs populate, machine type and canvas size correct |
| **`File > New`** | **Works.** Model picker lists all 17 machines, canvas-size dialog follows, blank document opens |

## Wine patches (in `patches/`)

Five fixes to Wine's `msado15`. Four were bare `E_NOTIMPL` stubs; the fifth is a
wrong answer rather than a missing one. None is app-specific and all are
upstreamable.

### `0001-msado15-implement-command_Execute.patch`

Covers two entry points plus a cursor-selection fix.

`ADODB.Command.Execute` was a bare stub, and the app runs all its SQL through
it. The fix is small because `get_rowset()` in `recordset.c` *already* has an
`ICommandText` fallback: it tries the source as a table name first, then
executes it as a command. So `command_Execute` mirrors `connection_Execute` and
delegates to `_Recordset_Open`. It logs a FIXME if parameters are ever passed,
so silently wrong results cannot happen unnoticed.

`Command.put_ActiveConnection` (the VARIANT overload, which is where any
IDispatch or scripting caller lands) was also a stub; it now accepts either a
live connection or a connection string and hands off to the putref path.

Finally, `Command.Execute` asks the provider for a **static** cursor when the
connection is `adUseClient`, rather than forward-only. Real ADO fetches
adUseClient rows through the client cursor engine, which is always static and
scrollable, and callers rely on that — `MoveLast` on the result is legal on
Windows. Requesting a static cursor is what gets `DBPROP_IRowsetLocate`
requested, which is in turn what makes bookmarks and `MoveLast` work.

### `0002-msado15-implement-recordset-Collect.patch`

`Collect` is the property behind the recordset's default member — `rs("Base")`
in the app's case. Wine already implemented `Fields.Item()` (including lookup by
name) and `Field.Value`, so `Collect` is just shorthand over those. Getter and
setter are implemented that way.

### `0003-msado15-recordcount-for-providers-without-IRowsetExactScroll.patch`

**This is the one that fixes `File > Open`.** `Recordset.RecordCount` returned
`-1` for *every* query against ACE, because Wine only answers it when the
provider implements `IRowsetExactScroll` — and ACE does not (its rowsets report
`DBPROP_IRowsetScroll` false). On Windows the count is exact regardless, because
`adUseClient` routes the rows through the client cursor engine, which has them
all in memory.

Wine has no client cursor engine over a live rowset, so the patch counts the
rows once: on `put_Rowset`, for an `adUseClient` recordset whose provider offers
no `IRowsetExactScroll`, it walks the rowset with `GetNextRows` and calls
`RestartPosition`. That happens before the recordset has been positioned, so the
cursor ends up exactly where the caller expects it. Server-side cursors are left
alone — fetching those eagerly would be a real regression — and the walk is
skipped unless `DBPROP_CANSCROLLBACKWARDS` is set, since otherwise there is no
getting back.

Verified directly, before and after, against `HengJi.accdb`:

| query | stock Wine | patched |
|---|---|---|
| `SELECT * FROM Factory` | -1 | **39** |
| `SELECT * FROM machine` | -1 | **24** |
| `SELECT * FROM FuncLineAndType WHERE MachineId = 0` | -1 | **133** |
| the `FuncLineAndType` UNION the app actually runs | -1 | **129** |

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

---

## How the `File > Open` crash was tracked down

Worth reading before debugging anything else here; the same route will work
again.

The symptom was a wild write:

```
Unhandled page fault on write access to 0861000C at address 1001D189
```

1. **Make it reproducible without a human.** The app takes a filename on the
   command line, and MFC turns that into the same `OpenDocumentFile` call the
   menu makes. `scripts/23-repro-open.sh` launches it on a private Xvfb display,
   waits for the "document version is at lower level" prompt, clicks it, and
   reports whether it crashed — one command, no clicking. That turned a
   multi-minute manual cycle into a 20-second one, which is what made the rest
   practical.

2. **Establish blast radius.** `scripts/24-survey-docs.sh` ran all 26 shipped
   samples: every one crashed at the same instruction. So this was not a
   legacy-format edge case but the main path.

3. **Disassemble rather than trust the debugger.** Wine's crash dialog gives a
   register dump and module map (click 详细信息 on 程序错误) but its backtrace is
   always empty — winedbg cannot unwind 32-bit stacks under WoW64. The faulting
   address maps to `BaseMachine.dll + 0x1D189`; `objdump -d --start-address=`
   showed a loop `for (j = 0; j < p->count; j++) p->items[j] = ...` over an array
   the constructor sizes at a fixed 160 elements.

4. **Name the function from the export table.** `objdump -p` plus the ordinal
   and name tables map the RVA to an exported symbol:
   `CBaseMachineType::Serialize(CArchive&, unsigned, CString, CDocument*)`.
   Nearby `.rdata` strings gave the source file (`BaseMachineType.cpp`).

5. **Read the actual value with gdb.** Breakpoints destabilise gdb in a WoW64
   process, but catching the fault does not. Attach, `handle SIGUSR1 nostop
   noprint pass` (wine uses it to suspend threads, and stopping on it derails
   everything), `continue`, and read `$ecx` at the SIGSEGV. The counter was
   `0xFFFFFFFF`, and walking the object list showed exactly one canvas of nine —
   `VIEW_TYPE_FUNC_LINE` — holding it; the other eight held 0.

6. **Follow it back to the source of the number.** The func-line canvas is the
   only one whose setup runs a query, found by disassembling HengJi.dll's
   `InitCanvasList` and reading the format string it passes: a `UNION` over
   `FuncLineAndType`. In the ADO trace the app opens that recordset, calls
   `MoveLast`, calls `get_RecordCount`, and closes it immediately — the classic
   row-count idiom. Wine handed it -1.

7. **Confirm in isolation.** A five-line VBScript through the same ACE
   connection reproduced `RecordCount = -1` for every query, with no app
   involved.

## Root causes found and fixed

Each of these was mistaken for the previous one until isolated.

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

### 4. `调用失败` / `0x80004005` — the connection string

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

### 5. Missing Jet expression service

Access Runtime ships `ACEES.DLL` but not the `VBAJET32.DLL` it loads at runtime,
breaking any query needing expression evaluation (error `#3092`). Supplied from
MDAC 2.8 by `scripts/19-install-jet-expression-service.sh`.

### 6. `尚未实现。` — unimplemented ADO

`Command.Execute` and `Recordset.Collect` were `E_NOTIMPL` stubs in Wine, both
surfacing as the same useless dialog. See patches 0001 and 0002.

### 7. `RecordCount` always -1 — the document crashes

The interesting one, and the subject of the whole walkthrough above. Wine
answered `Recordset.RecordCount` only for providers implementing
`IRowsetExactScroll`; ACE does not, so every query returned -1.

That single wrong answer produced both blockers. `File > Open` crashed because
the app stored the -1 as the element count of a fixed 160-entry array and then
looped `for (j = 0; j < count; j++)` over it — unsigned, so four billion
iterations, trampling ~150 KB of heap before hitting a read-only page.
`File > New` reported 内存不足 because MFC could not find dialog template 3001:
that dialog lives in `HengJi.dll`, the machine-specific extension DLL, which is
only brought in once the machine configuration resolves — and it could not
resolve while every row count came back as -1. Both were fixed by patch 0003
alone; nothing about resources or `CDynLinkLibrary` needed touching.

---

## Dead ends (don't retry these)

- **`winetricks mdac28` / `nt40`** — refuse on any win64 prefix.
- **`WINEARCH=win32` prefix** — impossible: Arch's Wine is WoW64-only
  (`WINEARCH is set to 'win32' but this is not supported in wow64 mode`).
  Multilib is disabled and not needed by this Wine build.
- **Native MDAC 2.8 `msado15`** — a regression, not a fix. Native ADO demands
  CLSID `{6c736db1-bd94-11d0-8a23-00aa00b58e10}` when `ADODB.Connection` is
  created. That GUID appears in **no** cab and **no** `.inf` in MDAC 2.8, and in
  nothing else installed on this system. With it in place the app dies silently
  instead of showing an error. Installing the full MDAC set (cursor engine,
  `msdaps`, `msdasc`, `msdaenum`, `msdaprst`, RDS) did not satisfy it either.
- **Registering `Flash10t.ocx`** — the app ships this ActiveX control and the
  installer never registers it. It fixed nothing.
  `scripts/21-register-app-ocx.sh` still does it; Flash is end-of-life, so
  unregister it (`regsvr32 /u`) if you would rather not keep it.
- **`HQ-PDS16(980).exe /extract_all:`** — InstallShield error 1152.
- **InstallShield record mode (`/r /f1`)** — produces no `setup.iss` here, so the
  GUI install cannot be replayed silently.
- **Chasing `IStorage`** — `.pds` files *are* OLE compound documents and
  `HxPDS.exe` imports `StgOpenStorage`, which makes Wine's structured storage
  look like a suspect. It is not involved: `WINEDEBUG=+storage` produces no
  output at all during a document open.
- **gdb breakpoints in the app** — setting one in 32-bit code inside the WoW64
  process leaves gdb reporting the breakpoint as a SIGSEGV at a bogus
  `0xffff80bb........` address and then losing the thread. Catching signals
  works fine; planting breakpoints does not.

## Untested unknowns

- **SoftDog USB dongle.** The package ships `SoftDogSetup.dll` /
  `SoftDogInstdrv.exe` and an "Install SoftDog" shortcut. It was deliberately
  skipped. Wine cannot load Windows kernel-mode drivers, so if the app requires
  the physical dongle for some operations there is a second wall behind this one.
- **Saving, compiling and exporting.** Only opening is verified. `Compile.dll`
  also imports `StgCreateDocfile`, so saving may exercise structured storage even
  though opening does not.
- **`MSXML 4.0` and SOAP Toolkit 3.0** are unregistered (Wine ships MSXML 3/6
  only), but a COM trace showed the app requests neither at startup.

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
- App's own logs (`all_msgs.log` etc., log4cplus) stay 0 bytes. Logging is
  configured at TRACE with a console appender, so it is not a configuration
  problem — the app simply only logs on error paths it never reaches.
- Prefix: `~/.wine-hqpds`, WoW64, `ACP=936`, win10

### Scripts (`scripts/`)

Run in order for a clean rebuild. Only step 05 needs mouse/keyboard.

| Script | Purpose |
|---|---|
| `env.sh` | Shared config — prefix, `LANG=zh_CN.UTF-8`, DPI, paths, `hq_wine` |
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
| `11-install-mdac.sh` | MDAC via its own installer — *installer fails, but the extraction is what matters* |
| `12-native-oledb32.sh` | **Required** — native `oledb32`/`msdatl3`/`msdart` |
| `13-native-ado.sh` | Native ADO — *regression, do not run* |
| `14-revert-native-ado.sh` | Undo 13 |
| `15-full-native-mdac.sh` | Full native MDAC set — *did not help* |
| `16-restore-best-state.sh` | Return to furthest-working config |
| `17-install-patched-msado15.sh` | Drop patched DLL in prefix — *insufficient, see 18* |
| `18-install-patched-msado15-system.sh` | **Install patched msado15 (needs sudo)** |
| `19-install-jet-expression-service.sh` | **vbajet32 + expsrv — fixes `#3092`** |
| `20-build-msado15.sh` | Fetch wine source, apply patches, build |
| `21-register-app-ocx.sh` | Register `Flash10t.ocx` — *did not fix anything* |
| `22-open-doc.sh` | Open a `.pds` from the command line (same path as the menu) |
| `23-repro-open.sh` | **Full unattended open-a-document cycle on the private display** |
| `24-survey-docs.sh` | Open every shipped sample and report which crash |
| `25-recordcount-check.sh` | One-line before/after test for the `RecordCount` bug |
| `30-xvfb.sh` | Start/stop the private X display |
| `apppid.sh` | Find or kill the real app process among its three lookalikes |
| `ui.sh` | Find/screenshot windows; click and type on the private display only |

After a rebuild, re-apply `12-native-oledb32.sh` (needs
`downloads/MDAC_TYP.EXE`, sha256
`157ebae46932cb9047b58aa849ac1885e8cbd2f218810cb83e57613b49c679d6`, extracted to
`downloads/mdac_x/`).

### Debugging setup

GUI work runs on a private Xvfb display (`:9`) rather than the real desktop, for
two independent reasons. X returns no pixels for the covered part of a window,
so a window behind anything else cannot be screenshotted at all — `import` and
ffmpeg's `x11grab` both fail with `BadMatch`. And synthetic input on a shared
desktop is unreliable, because focus and window ids shift under other
applications between actions. A display with one client has neither problem.

```sh
scripts/30-xvfb.sh start
DISPLAY=:9 scripts/ui.sh find              # list windows
DISPLAY=:9 scripts/ui.sh shot HqPDS out.png
WINEDEBUG=+seh scripts/23-repro-open.sh    # launch, dismiss prompt, report
```

Two traps worth knowing:

* `import -window <id>` is broken in current ImageMagick — it exits "missing an
  image filename" for every window id, valid or not. `ui.sh shot` grabs the root
  window and crops instead.
* Pass `HQ_VDESKTOP=2400x1500` (which `23-repro-open.sh` does) so wine runs
  inside its own desktop window. There is no window manager on `:9`, so without
  it nothing stacks or takes focus and the app's modal dialogs are unreachable.
