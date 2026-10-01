# Apps

## Choosing apps at install

`--apps` takes a comma-separated list; every install also gets `git`,
`wget`, `curl` and `openssh`.

| App | id | Termux packages |
|-----|----|-----------------|
| VS Code (Code - OSS) | `vscode` | `code-oss` |
| Firefox | `firefox` | `firefox` |
| Chromium | `chromium` | `chromium` |
| VLC | `vlc` | `vlc` |
| GIMP | `gimp` | `gimp` |
| LibreOffice | `libreoffice` | `libreoffice` |
| Python 3 + pip | `python` | `python`, `python-pip` |
| Node.js | `nodejs` | `nodejs` |
| Build tools | `build` | `clang`, `make`, `cmake`, `pkg-config` |

Anything else from Termux's repositories can go in `--packages`, e.g.
`--packages htop,neovim,tmux`. Names are checked before anything runs.

## VS Code

There are two ways to run VS Code, because Microsoft only publishes builds
for glibc Linux and Termux uses Android's libc.

| | Code - OSS (`vscode`) | Microsoft VS Code (`vscode-ms`) |
|-|----------------------|----------------------------------|
| Runs | natively in Termux | in a Debian proot |
| Extensions | [Open VSX](https://open-vsx.org) | Microsoft Marketplace |
| Speed | faster | slower (proot), plus ~1.5 GB for Debian |
| Install | `--apps vscode` or `terminux app vscode` | `--with vscode-ms` or `terminux app vscode-ms` |

Both get a desktop shortcut and are started with `--no-sandbox` (Android
doesn't allow Electron's setuid sandbox). terminux also writes
`"password-store": "basic"` into VS Code's `argv.json`; without a desktop
keyring, sign-ins (GitHub, Settings Sync) otherwise fail to save.

Some Microsoft extensions (Remote-SSH, Pylance, C# Dev Kit, Live Share) are
licensed only for Microsoft's builds; use `vscode-ms` if you need them.

## Cursor CLI

`--with cursor` or `terminux app cursor` installs Cursor's `agent` CLI in the
Debian proot. Cursor bundles a glibc Node.js and glibc native modules, so the
native Termux install fails with `required file not found` or
`libdl.so.2 not found`; terminux removes any such broken copy. Run it with:

```sh
terminux debian -- agent
```

## The Debian environment

`--with debian` (or `terminux app debian`) installs a full Debian userland
with [proot-distro](https://github.com/termux/proot-distro), and creates your
account (`--user`) with passwordless `sudo`. It shares Termux's `/tmp`, so
Linux apps inside it open on the same Termux:X11 display.

```sh
terminux debian              # a shell as your user
terminux debian -- htop      # run one command
```

Inside, `apt` works as on any Debian machine. It's slower than native Termux
because every system call goes through proot, so terminux only uses it for
software that has no Termux build (Microsoft VS Code, Cursor).
