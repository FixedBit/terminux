# Development

How to work on terminux: running the tests, adding a feature, and the
conventions the code follows.

## Running the tests

You don't need a phone. Every test runs in a throwaway `$HOME` and `$PREFIX`,
with Android commands (`getprop`, `pkg`, `termux-x11`, `proot-distro`, …)
replaced by stubs.

```sh
# one-time: bats-core and shellcheck
git clone --depth 1 https://github.com/bats-core/bats-core.git ~/bats-core
pip install shellcheck-py          # or your package manager's shellcheck

~/bats-core/bin/bats tests/        # behaviour
shellcheck -x bin/terminux lib/*.sh install.sh
node --test site/tests/            # the wizard's command builder
```

CI runs the same commands on every push and pull request
(`.github/workflows/ci.yml`).

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
[ADR 0005](adr/0005-options-schema.md).

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
