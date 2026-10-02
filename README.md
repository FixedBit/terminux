# terminux

Linux on your Android phone, set up with one command. A full desktop in
Termux:X11, VS Code, AI coding tools, and as many Linux environments as you
want, running in Termux without root.

**Build your install command with the wizard: https://fixedbit.github.io/terminux/wizard.html**

Or take the defaults (XFCE, VS Code, Firefox, VLC, Python, zsh with Oh My Zsh
and Powerlevel10k). Paste this into a fresh Termux:

```sh
curl -fsSL https://fixedbit.github.io/terminux/install.sh | bash
```

Get Termux from [F-Droid](https://f-droid.org/packages/com.termux/) or
[GitHub](https://github.com/termux/termux-app/releases), not the Play Store.
The installer sets up the Termux:X11 and Termux:API apps itself.

## What you get

- **A desktop**: XFCE, LXQt, MATE or KDE Plasma, with Turnip GPU acceleration
  on Adreno phones and a software fallback when the GPU isn't supported yet.
- **Fixes for real phones**: wake lock, Android's process killer, Samsung's
  audio, touch-friendly windows and automatic HiDPI. Tested on a Galaxy Z
  Fold, safe everywhere else.
- **VS Code**: the native build, or Microsoft's in a Debian environment.
- **AI tools**: Claude Code, Codex CLI, Gemini CLI, OpenCode, GrapeRoot,
  Aider, Cursor CLI, Ollama and llama.cpp, plus Continue and Cline for VS Code.
- **Environments**: separate proot containers for development, a second
  desktop, gaming, a minimal Alpine box or Kali for authorized security work,
  each with your own user and sudo.
- **NetBird**: put the phone on your private mesh without root. Keys are
  given at install time and never stored.
- **zsh** set up the way you'd set up a workstation, and a banner every time
  Termux opens that tells you what's running and what to type.

## Using it

```sh
terminux            # a menu with everything
terminux start      # start the desktop, then open Termux:X11
terminux add        # install more: AI tools, dev tools, media, network
terminux env        # your Linux environments: create, enter, back up, remove
terminux doctor     # find problems;  terminux fix  repairs them
terminux update     # pull the latest terminux
terminux help       # every command
```

Already running a desktop from linux-android or a similar script? Clone this
repo and run `bin/terminux fix` to repair it in place.

## Docs

Everything is on the [docs site](https://fixedbit.github.io/terminux/docs.html),
and in [`docs/`](docs/):
[getting started](docs/GETTING-STARTED.md) ·
[troubleshooting](docs/TROUBLESHOOTING.md) ·
[apps and AI tools](docs/APPS.md) ·
[environments](docs/ENVIRONMENTS.md) ·
[NetBird](docs/NETBIRD.md) ·
[architecture](docs/ARCHITECTURE.md) ·
[design decisions](docs/adr/).

## Testing

No phone needed for most of it:

- `bats tests/`: 220+ behaviour tests. Android commands are stubbed, the
  installer's generated scripts are actually run.
- `node --test site/tests/*.test.js`: the wizard's command builder.
- `tools/container-test.sh`: the real thing inside
  [termux-docker](https://github.com/termux/termux-docker). Package names
  against Termux's repos, the NetBird client under proot, zsh, and real
  Debian and Alpine environments.

What still needs a phone: the GPU, the Termux:X11 display and Android's
process limits. See [development](docs/DEVELOPMENT.md).

## Credits and licence

Apache 2.0. terminux builds on
[linux-android](https://github.com/mayukh4/linux-android) by Mayukh Bagchi
(MIT) and [ternux](https://github.com/soobujmiah/ternux) by Sobuj Miah
(Apache 2.0); see [NOTICE](NOTICE) and [CREDITS](CREDITS.md) for everything
that helped.
