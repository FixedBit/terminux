# Troubleshooting

Start with `terminux doctor`. It checks for every problem on this page that
it can detect and tells you the command that fixes it; most of them are
fixed by `terminux fix`.

## The desktop

| What you see | Why | Fix |
|--------------|-----|-----|
| Termux:X11 stays black, or "X server already running on display :0" | A previous X server was killed and left its lock file behind | `terminux fix`, then `terminux start` |
| The desktop disappears, Termux shows `signal 9` | Android 12+'s phantom process killer | `terminux fix phantom`; set Termux to Unrestricted battery use |
| Everything freezes when you switch to Termux:X11 | Battery saver suspended Termux | Keep the `wakelock` [tweak](DEVICE-TWEAKS.md) on; set Termux to Unrestricted battery use |
| Everything is tiny | Native resolution at 96 DPI | `terminux dpi 180` (try 150–200), then `terminux restart` |
| Everything is blurry | Termux:X11 is scaling a lower resolution | `terminux display native` with a higher DPI |
| KDE windows have no title bars | KWin can't use OpenGL ES on Termux:X11 | `terminux fix` (sets `KWIN_COMPOSE=N`) |
| Choosing KDE never starts Plasma | A bug in the original launcher (`nexec`) | `terminux fix` |
| Apps crash, or `vulkaninfo` shows llvmpipe | Mesa's Turnip driver doesn't support this GPU yet | Nothing to do now; the `gpu-check` tweak switches to software rendering automatically. `pkg upgrade` later may add support |
| No sound on a Samsung phone | One UI's audio needs a library preloaded | Keep the `oneui-audio` tweak on |

Harmless warnings you can ignore: anything about D-Bus's system bus,
ConsoleKit, UPower, PowerDevil, DPMS or PowerProfiles. Android doesn't have
them and the desktop works without them.

## Apps

| What you see | Why | Fix |
|--------------|-----|-----|
| `node: cannot execute: required file not found` running Cursor's `agent` | Cursor ships programs built for regular Linux (glibc), and Termux uses Android's libc | `terminux app cursor` installs it in the Debian environment |
| `libdl.so.2 not found` | Same: a regular-Linux program in Termux | Install it in an [environment](ENVIRONMENTS.md) instead |
| VS Code forgets your GitHub sign-in | No desktop keyring | `terminux fix` (sets `password-store` to `basic`) |
| A VS Code extension is missing from the store | code-oss uses Open VSX, which doesn't have Microsoft-only extensions | `terminux app vscode-ms` for Microsoft's build |

## NetBird

| What you see | Fix |
|--------------|-----|
| `invalid setup-key` | The key expired, was used up, or has a typo. Make a new one in the NetBird dashboard and run `terminux netbird join` again |
| Peers can't reach the phone | Check `terminux netbird status`; the service you want (e.g. `sshd`) must be running on the phone |
| The phone can't reach peers | Termux programs reach the mesh through the SOCKS5 proxy on `127.0.0.1:1080`; see [NetBird](NETBIRD.md) |

## Still stuck

`terminux info` prints your device, Android version and GPU. Include it, and
the output of `terminux doctor`, when you
[open an issue](https://github.com/FixedBit/terminux/issues).
