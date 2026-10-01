# Architecture

terminux sets up and runs a Linux desktop on an Android phone inside Termux,
without root. This page explains how the pieces fit; the reasoning behind
each major choice is in [the decision records](adr/).

## The pieces

```text
 GitHub Pages wizard ──builds──▶ one command ──pasted into──▶ Termux
 (site/, reads options.json)                                    │
                                                                ▼
                                                     install.sh (bootstrap)
                                         clones the repo, parses flags, runs:
                                                                │
              ┌─────────────────────────┬───────────────────────┼─────────────────────┐
              ▼                         ▼                       ▼                     ▼
  setup/termux-linux-setup.sh   terminux app <name>     terminux netbird join   terminux doctor
  desktop, GPU, audio, launchers  VS Code, proot apps    private mesh            health report
              │
              ▼
  ~/start-linux.sh  ◀── terminux start / stop / status / display / fix
```

| Part | Role |
|------|------|
| `options.json` | The install options: names, types, allowed values, help text. The one source of truth shared by the wizard, `install.sh` and the tests. |
| `site/` | Static GitHub Pages wizard. Renders a form from `options.json` and prints the command to paste. Never asks for secrets. |
| `install.sh` | Bootstrap. Works when piped from `curl`: clones the repo, re-runs itself from the checkout with the terminal attached, validates flags, then carries out the plan. `--dry-run` prints the plan only. |
| `setup/termux-linux-setup.sh` | The desktop installer inherited from linux-android, patched for the Fold. Generates `~/start-linux.sh`, `~/stop-linux.sh` and `~/.config/linux-gpu.sh`. |
| `bin/terminux` | The permanent control command, linked into `$PREFIX/bin`. Dispatches to `lib/<module>.sh`. |
| `lib/` | One module per concern (desktop, display, doctor, fix, apps, netbird, private config). Modules are plain bash functions, testable by sourcing. |
| `tests/` | bats suites. Every test runs in a throwaway `$HOME` and `$PREFIX` with stubbed Android commands. |

## Where things live on the phone

| Path | Contents |
|------|----------|
| `~/.local/share/terminux` | The git checkout (`terminux update` pulls here) |
| `$PREFIX/bin/terminux` | Symlink to the checkout's `bin/terminux` |
| `~/.config/terminux/config` | Non-secret settings chosen at install (`KEY=VALUE`, parsed, never sourced) |
| `~/.config/terminux/private.env` | Optional private values, mode 0600, never in git |
| `~/.local/state/terminux/` | Runtime state: NetBird identity and logs |
| `~/.config/linux-gpu.sh` | GPU/DPI environment written by the desktop installer |

## Two runtimes

The desktop runs **natively in Termux** (bionic libc, Termux packages): it is
faster, and Turnip GPU acceleration works without extra layers. Some software
only exists as glibc builds — Microsoft VS Code, Cursor. Those run in an
optional **Debian proot** that terminux creates on demand and shares the same
X display with. See [ADR 0001](adr/0001-native-termux-with-optional-proot.md).

## Secrets

The public repo holds no keys, server addresses or personal settings. Private
values reach the phone at install time: typed at a hidden prompt, passed as
environment variables, or loaded from a private file or link that is parsed
(never executed) against an allow-list. See
[ADR 0003](adr/0003-secrets-at-runtime.md).

## Testing

Each feature starts as a failing bats test. Code that only makes sense on
Android (`getprop`, `pkg`, `termux-x11`, `proot-distro`) is reached through
commands on `PATH`, so tests replace them with stubs and assert on what
terminux asked them to do. The inherited installer is covered by
characterization tests that render its launchers in a sandbox and check them.
See [DEVELOPMENT.md](DEVELOPMENT.md).
