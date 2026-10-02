# Desktops

terminux installs one desktop environment natively in Termux and shows it in
the **Termux:X11** app. Pick one in the wizard (`--de`).

| Desktop | Flag | RAM | Notes |
|---------|------|-----|-------|
| XFCE | `--de xfce` | 3 GB+ | **Recommended.** Light, very configurable, and its window manager needs no GPU, so it's the most reliable on new phones. Gets a macOS-style dock (Plank). |
| LXQt | `--de lxqt` | 2 GB+ | The lightest. Good for older or low-RAM phones. |
| MATE | `--de mate` | 3 GB+ | Classic two-panel layout. Also gets Plank. |
| KDE Plasma | `--de kde` | 6 GB+ | Modern and polished, but heavy. Window compositing is **off** by default because KWin can't get a GLES context on Termux-X11 (without this, windows lose their title bars). Set `KWIN_GL=1` when installing to try OpenGL compositing through Zink. |

## Windows apps

`--wine` adds Wine with Box64/Hangover (about 500 MB), which runs some x86
Windows programs on ARM. Expect simple utilities to work; games and anything
needing .NET or DirectX 12 mostly won't.

## Starting and stopping

```sh
terminux start      # also starts NetBird if this phone is enrolled
terminux stop
terminux status
```

Open the **Termux:X11** app after `terminux start`. The generated scripts
`~/start-linux.sh` and `~/stop-linux.sh` still work on their own.

## When the desktop dies

Android 12 and later kill "phantom" child processes, which takes the
desktop down with `signal 9`. Run `terminux doctor`; if it reports the
process killer as enabled, run `terminux fix phantom`, or turn on
**Developer options → Disable child process restrictions**.

More symptoms and fixes: [Troubleshooting](TROUBLESHOOTING.md).
