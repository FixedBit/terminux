# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed
- KDE Plasma: no window title bars (`KWIN_COMPOSE=O2ES` → `N`), and the KDE
  launcher never starting Plasma (literal `\n` in the generated launcher).
- Black screen / "X server already running" after a killed X server.
- Desktop freezing when Samsung suspends Termux (wake lock).
- Crashes on GPUs Turnip doesn't support yet (software-rendering fallback).
- Unreadably small UI on the Galaxy Fold (`LINUX_DPI`).

### Added
- VS Code (`code-oss`) in the default install, with a desktop shortcut.
- Phantom-process-killer and Termux-X11 display hints on the completion screen.
- Repository scaffold: licensing and attribution for the upstream projects.
