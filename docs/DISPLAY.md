# Display and look

## Resolution: native vs scaled

Termux:X11 can render at the screen's **native** resolution (sharp, but tiny
at the default 96 DPI) or at a **scaled** lower resolution (readable, but
blurry). terminux uses native resolution and raises the DPI instead, which is
both sharp and readable.

```sh
terminux display native   # sharp; pair with a high DPI (default)
terminux display scaled   # blurry but quick; 150% scale
terminux display fold     # native + fullscreen + hide the camera cutout
```

These change Termux:X11's preferences, which only works while the Termux:X11
app is open; terminux runs the change in the background so nothing hangs.

## DPI

`--dpi` in the wizard, or later:

```sh
terminux dpi          # show the current value
terminux dpi 180      # set it; restart the desktop to apply
```

Leave it unset and the `hidpi` [device tweak](DEVICE-TWEAKS.md) picks one:
**180** on a Galaxy Z Fold (models `SM-F9xx`), 40% of Android's screen
density on other high-density phones, and 96 on ordinary screens. Good
starting points:

| Screen | DPI |
|--------|-----|
| Galaxy Fold, inner screen | 160–200 |
| Galaxy Fold, cover screen; most phones | 130–150 |
| Tablets | 120–160 |

The value is stored as `LINUX_DPI` in `~/.config/linux-gpu.sh` and applied at
desktop start through X resources, KDE's font DPI and XFCE's settings. The `touch` tweak also switches XFCE to the
`Default-xhdpi` window theme so borders are big enough to grab with a finger.

## Theme

`--theme dark` (default) or `--theme light` sets the widget theme (Adwaita or
Adwaita-dark) for GTK apps on every desktop (through `GTK_THEME`) and XFCE's
own theme setting. Change it later
from the desktop's own appearance settings.

## Touch input

```sh
terminux touch            # toggle
terminux touch trackpad   # finger moves a pointer, tap to click (precise)
terminux touch touch      # tap where you want to click; long-press = right click
```
