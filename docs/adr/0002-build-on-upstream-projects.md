# 0002 — Build on upstream projects; reuse code only under compatible licences

**Status:** Accepted, 2026-10-01

## Context

Four existing projects were studied:

| Project | Licence | What it offers |
|---------|---------|----------------|
| [mayukh4/linux-android](https://github.com/mayukh4/linux-android) | MIT | A working native desktop installer (XFCE/LXQt/MATE/KDE, Turnip, Wine) |
| [soobujmiah/ternux](https://github.com/soobujmiah/ternux) | Apache-2.0 | A clean modular CLI (`bin/` + `lib/`), doctor, device detection, bats tests |
| [miguelguerra200022-sudo/termux-vscode-x11](https://github.com/miguelguerra200022-sudo/termux-vscode-x11) | none (all rights reserved) | VS Code on Termux-X11 ergonomics |
| [arfshl/termux-proot-script](https://github.com/arfshl/termux-proot-script) | GPL-3.0 | Multi-distro proot installs |

terminux is licensed under Apache-2.0 ([ADR 0007](0007-apache-2-licence.md)).

## Decision

- **linux-android** is imported as the desktop installer, history preserved
  as an unmodified import commit followed by our changes.
- **ternux** code is adapted where useful (CLI layout, detection helpers);
  adapted files say so in their header and ternux's NOTICE ships in
  `LICENSES/`.
- **termux-vscode-x11** and **termux-proot-script** are used for ideas only.
  No code is copied: one has no licence, and the other's GPL-3.0 is not
  compatible with distributing terminux under Apache-2.0. Facts and techniques learned from them are re-implemented
  independently, for example: VS Code needs `"password-store": "basic"` in
  `argv.json` without a keyring; One UI's PulseAudio needs
  `LD_PRELOAD=/system/lib64/libskcodec.so` (termux-packages issue #19623);
  phantom-process limits can be lifted through root or Shizuku when available.

termux-vscode-x11 was also reviewed for safety and is **not** recommended as
a dependency: it auto-updates from a third-party Cloudflare Worker at every
launch, gates use behind a subscription check, and unpacks an encrypted
credential vault into `$HOME`.

## Consequences

- `NOTICE` must be kept accurate whenever code is adapted; `CREDITS.md`
  thanks the projects that contributed ideas.
- Bug fixes to the imported installer can be offered back upstream as diffs.
