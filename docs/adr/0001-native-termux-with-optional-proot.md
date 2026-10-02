# 0001 — Native Termux desktop, Debian proot only for glibc apps

**Status:** Accepted, 2026-10-01

## Context

There are two common ways to run a Linux desktop on Android without root:

- **Native Termux** (linux-android): the desktop and apps are Termux packages
  built against Android's bionic libc. Fast, and Termux's Mesa gives Turnip
  GPU acceleration on Adreno directly.
- **proot distro** (ternux, termux-proot-script): a full Debian/Ubuntu/Arch
  userland under proot. Any arm64 glibc binary runs, but every syscall is
  translated, and GPU acceleration needs Zink/VirGL plumbed across the
  container boundary.

The target device (Galaxy Z Fold, Adreno) benefits most from native GPU
access. But the user also needs Microsoft VS Code and the Cursor CLI, which
ship only as glibc binaries and fail natively (`required file not found`,
`libdl.so.2 not found`).

## Decision

The desktop runs natively in Termux. terminux creates a Debian proot on
demand, only when a glibc-only app is requested (`terminux app vscode-ms`,
`terminux app cursor`), and runs those apps against the same X display
(`proot-distro login --shared-tmp`).

VS Code itself defaults to `code-oss`, the native Termux build.

## Consequences

- The common path stays fast and simple; the proot cost is paid only by
  people who need glibc apps.
- Two package managers exist on the phone (`pkg` and Debian's `apt`); docs
  must say which one an app came from.
- Offering whole proot distros as the desktop (as termux-proot-script does)
  is possible later as another `--runtime` option without changing the CLI.
