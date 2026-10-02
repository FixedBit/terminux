# Credits

terminux stands on other people's work. Code we reuse is listed with its
licence in [NOTICE](NOTICE); everything else here informed the design.

## Code reused

| Project | Author | Licence | What we use |
|---------|--------|---------|-------------|
| [linux-android](https://github.com/mayukh4/linux-android) | Mayukh Bagchi | MIT | The native desktop installer (`setup/`), imported at `fb63e0d` and modified |
| [ternux](https://github.com/soobujmiah/ternux) | Sobuj Miah | Apache-2.0 | The `bin/` + `lib/` CLI layout, device detection and output helpers, adapted |

## Ideas and research

| Project | Author | Licence | What we learned |
|---------|--------|---------|-----------------|
| [termux-vscode-x11](https://github.com/miguelguerra200022-sudo/termux-vscode-x11) | miguelguerra200022-sudo | none published | VS Code ergonomics on Termux-X11: `password-store: basic`, touch/trackpad toggle, root → Shizuku → ADB for process limits |
| [termux-proot-script](https://github.com/arfshl/termux-proot-script) | arfshl | GPL-3.0 | Multi-distro proot layouts; the One UI PulseAudio workaround |
| [termux-packages #19623](https://github.com/termux/termux-packages/issues/19623) | Termux community | — | `LD_PRELOAD=/system/lib64/libskcodec.so` for PulseAudio on One UI |

No code from the projects in this table is included in terminux.

## Platforms and tools

- [Termux](https://termux.dev), [Termux:X11](https://github.com/termux/termux-x11)
  and [proot-distro](https://github.com/termux/proot-distro) — the foundation
  everything runs on.
- [Mesa](https://mesa3d.org) (Turnip, Zink) — GPU acceleration on Adreno.
- [NetBird](https://netbird.io) — the WireGuard mesh, and its netstack mode
  that makes a rootless client possible.
- [Code - OSS](https://github.com/microsoft/vscode) and [Open VSX](https://open-vsx.org).
- [bats-core](https://github.com/bats-core/bats-core) and
  [ShellCheck](https://www.shellcheck.net) — how we keep the scripts honest.

Spotted something of yours here without credit, or credited wrongly? Open an
issue and we'll fix it.
