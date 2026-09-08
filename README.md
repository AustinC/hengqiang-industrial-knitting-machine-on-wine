# 恒强 HQ-PDS16 (Hengqiang 980) under Wine

Scripts and Wine patches for running **恒强新一代制版系统（16把纱嘴）** —
Hengqiang's CNC flat-knitting pattern-design software — on Linux via Wine.

**Status: the app installs and runs to its full UI, but cannot open or create
documents yet.** See [`STATUS.md`](STATUS.md) for exactly what works, what
doesn't, and the diagnosis so far. Read that before investing time.

| | |
|---|---|
| Installs, correct Chinese paths and fonts | yes |
| Main UI, menus, drawing tools, colour panel | yes |
| Reads its encrypted Access databases | yes |
| `File > New` / `File > Open` | **no** — see [Open blockers](STATUS.md#open-blockers) |
| Hardware dongle (SoftDog) | untested |

## What you need

* A Linux box with Wine (developed against **11.17**, WoW64 build — Arch's
  `wine` package). Multilib/32-bit Wine is *not* required.
* `winetricks`, `unixodbc`, `cabextract`, `curl`, `xdotool`, ImageMagick.
* `clang` + `lld` if you want to build the Wine patches — these serve as the PE
  cross-compiler, so **mingw-w64 is not needed** (saves a ~1.2 GB install).
* **Your own copy of the vendor installers.** Nothing vendor-supplied is
  redistributed here:
  * `HQ-PDS16(980).exe` — the app itself, listed as "Hengqiang 980 Plate
    Making Software" (~214 MB) at the vendor's download centre:
    <https://www.hqcnc.com/download.html> (Zhejiang Hengqiang Technology Co.,
    Ltd.). An English manual is offered on the same page. Note the download
    buttons there are script-driven rather than plain links, so you may need to
    go through the page itself or their support line.
  * `AccessRuntime.exe` — Microsoft Access 2007 Runtime
  Put both in the repo root, or point `HQ_APP_INSTALLER` / `HQ_ACCESS_INSTALLER`
  at them.

On Arch:

```sh
sudo pacman -S --needed wine wine-mono wine-gecko winetricks unixodbc \
                        cabextract curl xdotool imagemagick clang lld
```

You also need a Chinese locale generated, or the installer writes mojibake
paths:

```sh
sudo sed -i 's/^#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen
```

## Install

Scripts live in `scripts/`, they are roughly numbered in run order but all aren't necessary for install. They use a **dedicated Wine
prefix at `~/.wine-hqpds`** so they cannot disturb an existing `~/.wine`.
Override with `WINEPREFIX=...` if you want somewhere else.

> `01-rebuild-prefix.sh` does `rm -rf "$WINEPREFIX"`. Check what `WINEPREFIX`
> points at before running it.

```sh
./scripts/01-rebuild-prefix.sh          # fresh prefix, zh_CN locale, HiDPI
./scripts/03-install-access.sh          # Access 2007 Runtime + ACE provider
./scripts/07-fonts.sh                   # CJK fonts and font aliases
./scripts/05-install-app-record.sh      # the app itself -- GUI, needs clicking
```

Only step 05 needs interaction. In its wizard: pick `中文 (简体)` as the setup
language, accept the licence, and accept the default install path. On the final
page **untick** "显示自述文件" (readme) and "安装数据库引擎" (database engine —
step 03 already did it, and running a second Access engine installer tends to
conflict); leave "安装运行库" ticked, since that VC++ redist supplies the
`mfc140u.dll` the app needs and Wine has no MFC of its own.

Then the fixes that are not optional:

```sh
./scripts/12-native-oledb32.sh              # native oledb32 -- see note below
./scripts/19-install-jet-expression-service.sh
./scripts/20-build-msado15.sh               # build the patched ADO
sudo ./scripts/18-install-patched-msado15-system.sh
```

`12-native-oledb32.sh` and `19-...` both need Microsoft's MDAC 2.8 package.
`11-install-mdac.sh` downloads and extracts it (checksum-verified) even though
its installer step fails on a WoW64 prefix — the extraction is what matters.

Run it:

```sh
./scripts/08-run.sh          # launches detached, logs to logs/run.log
```

## The Wine patches

`patches/` holds four fixes to Wine's `msado15` (ADO). Each was a bare
`E_NOTIMPL` stub; none is specific to this app, and all are upstreamable to
WineHQ:

* `_Command::Execute` — the app runs real SQL through it
* `_Recordset::Collect` (get and put) — the recordset's default member, `rs("x")`
* `_Command::put_ActiveConnection` — the VARIANT overload, needed by any
  IDispatch/script caller
* a static cursor when the connection is `adUseClient`, so `MoveLast` works

`20-build-msado15.sh` fetches Wine source matching your installed version,
applies them, and builds just `msado15.dll` (~10 s, not the whole tree).

Wine only ever loads a builtin DLL from its own install directory, so
`18-install-patched-msado15-system.sh` must replace
`/usr/lib/wine/i386-windows/msado15.dll` — hence the `sudo`. It backs the
original up alongside as `.stock`, and `... revert` restores it. **A Wine
package upgrade overwrites the patch**, so re-run it afterwards.

## Layout

```
scripts/    numbered install/diagnostic steps; env.sh holds shared config
patches/    Wine msado15 patches
STATUS.md   what works, root causes found, dead ends, open blockers
logs/       run logs and screenshots (gitignored)
```

Scripts that turned out to be dead ends are kept and labelled rather than
deleted, so nobody repeats them. `STATUS.md` has a "Dead ends" section listing
what not to retry and why.

## Contributing

The most useful thing right now is the document-open failure. `STATUS.md`
documents the trail: MFC cannot find dialog template 3001, which lives in
`HengJi.dll` rather than the exe, and the leading hypothesis is a failed
`BaseMachine.dll` → `HengJi.dll` handshake. It also records the diagnostic
techniques that worked, which is worth reading before starting — Wine's own
crash dialog beats `winedbg` here, and the app's crash handler buries faults
under millions of relay lines.

## Licence and scope

These scripts and patches are provided as-is. The Wine patches derive from
Wine's source and carry Wine's LGPL-2.1-or-later terms. No vendor installer,
runtime, or database is included or redistributed — bring your own licensed
copies.
