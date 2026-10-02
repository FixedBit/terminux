# Galaxy Z Fold notes

What was found while debugging the desktop on a Galaxy Z Fold 8 (One UI on
Android 16, Snapdragon/Adreno), Sept 27 – Oct 1 2026, and how terminux deals
with each problem. Most of it applies to any recent Samsung or Android 12+
phone.

## Problems and fixes

| # | Symptom | Root cause | Fix in terminux |
|---|---------|-----------|-----------------|
| 1 | `X server already running on display :0`, black screen | A killed Termux-X11 leaves `$PREFIX/tmp/.X0-lock` and `.X11-unix` behind | Launcher and stop script delete both |
| 2 | UI tiny (native resolution) or blurry (scaled) | Native resolution at 96 DPI on a ~370 ppi screen | `LINUX_DPI=180` on Fold models (`SM-F9*`), applied through xrdb, kcmfontsrc and xfconf |
| 3 | Cursor `agent`: `node: cannot execute: required file not found` | Cursor bundles a glibc `node`; Termux uses Android's bionic libc | Run Cursor inside a Debian proot: `terminux app cursor` |
| 4 | After symlinking Termux's node: `libdl.so.2 not found` loading `merkle-tree-napi` | Cursor's native modules are glibc too | Same as #3 — proot only |
| 5 | KDE: no title bars, `Could not fulfill the requested compositing mode` | Upstream sets `KWIN_COMPOSE=O2ES`; KWin can't get GLES on Termux-X11 | `KWIN_COMPOSE=N` (opt in to GL with `KWIN_GL=1`) |
| 6 | KDE choice never starts Plasma | Upstream `EXEC_CMD` has a literal `\n` inside the launcher heredoc, so it runs `nexec` | Real newline |
| 7 | Desktop dies at random with `signal 9` | Android 12+ phantom process killer | Developer options → **Disable child process restrictions**; `terminux doctor` checks it |
| 8 | Desktop freezes after switching to the Termux-X11 app | Samsung battery management suspends Termux | `termux-wake-lock` in the launcher |
| 9 | Apps or KWin crash under Zink | A brand-new Adreno can ship before Turnip supports it | Launcher runs `vulkaninfo --summary`; no Turnip device → software rendering |
| 10 | Microsoft VS Code won't start | Microsoft's builds are glibc | `code-oss` from Termux's x11-repo natively; Microsoft's build in proot (`terminux app vscode-ms`) |

Harmless noise you can ignore: D-Bus system bus, ConsoleKit, UPower,
PowerDevil, DPMS and PowerProfiles warnings. Android has none of these.

## Display settings

With the Termux-X11 app **open** (the command hangs otherwise):

```sh
termux-x11-preference displayResolutionMode:native fullscreen:true hideCutout:true
```

Then tune `LINUX_DPI` in `~/.config/linux-gpu.sh`: 180 suits the inner
screen, about 140 the cover screen. Restart the desktop to apply.

The quick-but-blurry alternative is `displayResolutionMode:scaled displayScale:150`.

## Still open

- Whether current Termux Mesa's Turnip supports the Fold 8's exact Adreno.
  Check on the device: `vulkaninfo --summary | grep -iE "turnip|adreno|llvmpipe"`.
- KWin with `KWIN_COMPOSE=N` aborted once when started by hand with
  `kwin_x11 --replace` from a backgrounded shell; the reason wasn't captured.
  If title bars are still missing after a full restart, run
  `DISPLAY=:0 kwin_x11 --replace` in a second Termux session and read the
  lines before `Aborted`. XFCE (`xfwm4`) doesn't need GL at all.
- Folding or unfolding while running in native mode resizes the X screen.
