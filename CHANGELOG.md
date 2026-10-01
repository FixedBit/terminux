# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-10-01

First release.

### Added
- One-command install for a fresh Termux, built with a web wizard on GitHub
  Pages. Choices travel in the page address, so a link sets up another phone
  the same way.
- Desktops: XFCE, LXQt, MATE, KDE Plasma, with optional Wine.
- Device tweaks, all on by default and safe where they don't apply: wake
  lock, GPU self-check with software fallback, Android's phantom process
  killer, Samsung One UI audio, touch-friendly windows, automatic HiDPI.
- Dark or light theme; DPI from the screen's density or set by hand.
- The `terminux` command: menu, start/stop/status, display/dpi/touch,
  doctor and fix, add, app, env, debian, netbird, ssh, update, uninstall,
  and a banner when Termux opens.
- An app catalog (`terminux add`): AI tools (Claude Code, Codex CLI, Gemini
  CLI, OpenCode, GrapeRoot, Aider, Cursor CLI, Ollama, llama.cpp, Continue and
  Cline), development, media, and network and sync tools.
- Environments (`terminux env`): any number of proot containers from
  profiles (dev, desktop, minimal, gaming, security), each with your user and
  sudo, sharing the display and audio.
- VS Code as code-oss with working sign-ins, Microsoft VS Code and the
  Cursor CLI in Debian.
- zsh with Oh My Zsh, Powerlevel10k, autosuggestions and syntax highlighting.
- NetBird mesh without root; setup keys are passed at install time and
  never stored.
- Automatic install of the Termux:X11 and Termux:API apps.
- Tests: bats behaviour tests, the wizard's node tests, and checks inside
  real Termux via termux-docker.

### Fixed (in the desktop installer inherited from linux-android)
- KDE Plasma: no window title bars (`KWIN_COMPOSE=O2ES` → `N`), and the KDE
  launcher never starting Plasma (literal `\n` in the generated launcher).
- Black screen / "X server already running" after a killed X server.
- Desktop freezing when Samsung suspends Termux.
- Crashes on GPUs Turnip doesn't support yet.
- Unreadably small UI on high-density screens.

[Unreleased]: https://github.com/FixedBit/terminux/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/FixedBit/terminux/releases/tag/v0.1.0
