# Development

How to work on terminux: running the tests, adding a feature, and the
conventions the code follows.

## Running the tests

You don't need a phone for most of it.

**Behaviour tests** run in a throwaway `$HOME` and `$PREFIX`, with Android
commands (`getprop`, `pkg`, `termux-x11`, `proot-distro`, ...) replaced by
stubs. Run them on Linux (on Windows, inside WSL; Git Bash works but skips a
few tests that need glibc).

```sh
git clone --depth 1 https://github.com/bats-core/bats-core.git ~/bats-core
~/bats-core/bin/bats tests/
node --test site/tests/*.test.js     # the wizard's command builder
node tools/sync-options.js --check   # options.json matches catalog.tsv and envs/
shellcheck -x -S warning --shell=bash bin/terminux install.sh lib/*.sh tools/*.sh
```

**Real Termux** runs terminux inside
[termux-docker](https://github.com/termux/termux-docker):

```sh
docker run --rm --privileged aptman/qus -s -- -p aarch64   # once, on x86 machines
tools/container-test.sh                  # all: smoke packages netbird shell debian
tools/container-test.sh netbird          # one
```

`smoke` and `packages` run on the aarch64 image, the phone's CPU under
emulation. Anything using proot runs on the x86_64 image, because QEMU's
user-mode emulation has no `ptrace`, which proot needs. Termux has no `/tmp`;
use `$TMPDIR` in container checks.

**Preview the site** with `tools/build-site.sh && python3 -m http.server -d _site`.

CI runs all of this on every push and pull request.

## Adding a feature (test first)

1. **Red.** Write a bats test for the behaviour in `tests/<module>.bats`.
   Run it and watch it fail for the reason you expect (the feature is
   missing, not a typo).
2. **Green.** Write the least code that makes it pass.
3. **Refactor**, keeping everything green.
4. Document it: the command's help text, the relevant page in `docs/`, and a
   line under *Unreleased* in `CHANGELOG.md`.
5. Commit with a message that says *why*.

A new CLI command is a `cmd_<name>` function in `lib/<module>.sh` plus one
line in `_module_for` in `bin/terminux`. `tests/cli.bats` fails if help
advertises a command that no module defines.

A new install option starts in `options.json`; see
[ADR 0005](adr/0005-options-schema.md). A new app is one line in
`catalog.tsv` followed by `node tools/sync-options.js`; a new environment
profile is a file in `envs/`.

## Conventions

- **bash, not sh.** Scripts run under Termux's bash. `set -u` in entry points.
- **Never source user-controlled files.** Settings are `KEY=VALUE` and read
  with `tx_kv_get`. Private values are parsed against an allow-list.
- **No secrets in argv.** Pass them through 0600 files or stdin.
- **Anything that can hang runs detached** (`tx_run_detached`):
  `termux-x11-preference` blocks while the Termux-X11 app is closed.
- **Generated launchers are heredocs.** In `setup/termux-linux-setup.sh`,
  runtime variables in `<< LAUNCHEREOF` blocks are escaped (`\$VAR`) and
  install-time ones are bare. Multi-line values need real newlines, never
  `\n` — that mistake is how upstream's KDE launcher ran `nexec`.
- **LF line endings everywhere** (`.gitattributes` enforces it). CRLF breaks
  bash on Android.
- New files start with `# SPDX-License-Identifier: Apache-2.0`. If you adapt
  code from elsewhere, check its licence ([ADR 0007](adr/0007-apache-2-licence.md)),
  say where it came from in the header and update `NOTICE`.

## Commit messages

Imperative subject under ~70 characters, a blank line, then what changed and
why. Reference the ADR when a commit implements or changes a decision.
