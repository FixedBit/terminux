# Troubleshooting

Start with `terminux doctor`. It checks for every problem on this page that
it can detect and tells you the command that fixes it; most of them are
fixed by `terminux fix`.

## The install stops

When a step fails, the installer now tells you which step, shows the actual
error lines, explains the likely cause and gives the command that fixes it.
Package problems it can repair safely, it repairs and retries by itself.

| What it says | Why | Fix |
|--------------|-----|-----|
| Two packages both claim the same file ("trying to overwrite") | Another setup script installed its own version of a package (often a graphics driver) that Termux now ships too | `terminux fix packages` |
| "Upgrade hit a library conflict" (older versions) | Usually the same file conflict, or an interrupted install | Update terminux (`terminux update`), then `terminux fix packages` and run the install again |
| An install was interrupted | Termux was closed or Android killed it mid-install | `terminux fix packages` |
| Couldn't reach the package server | Connection, VPN or data saver | Check your connection, or `termux-change-repo` |
| Hash sum mismatch | The mirror is mid-update | `termux-change-repo`, pick another mirror |
| `curl` or `git`: `cannot locate symbol "SSL_..."` | An earlier upgrade stopped half way, so curl is newer than OpenSSL | `dpkg --configure -a`, `apt update`, `apt install -y openssl`, `apt full-upgrade -y`, then reopen Termux. (apt doesn't need curl, so it still works.) |
| `CANNOT LINK EXECUTABLE` | A core library was upgraded while Termux was running | Close Termux completely, reopen, `pkg upgrade`, run the install again |
| Out of space | The phone is full | Free about 4 GB |

Run the same install command again after fixing; packages that are already
installed are skipped. `terminux doctor` also spots half-installed packages.

To get help, run `terminux report`. It saves one file with your device
details, `terminux doctor`, your package sources and the relevant logs, with
setup keys, tokens and anything in `private.env` replaced by `REDACTED`, ready
to attach to an issue.

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

Run `terminux report` and attach the file it makes when you
[open an issue](https://github.com/FixedBit/terminux/issues).
