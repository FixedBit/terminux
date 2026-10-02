# 0005 — One options schema drives the wizard, the installer and the tests

**Status:** Accepted, 2026-10-01

## Context

Users configure their install (desktop, theme, apps, extra packages, NetBird,
proot apps) in a web wizard hosted on GitHub Pages, which prints a command to
paste into Termux. The wizard and `install.sh` are written in different
languages and would drift apart if each kept its own list of options.

## Decision

`options.json` at the repo root is the single definition of every install
option: flag name, type (`choice`, `multi`, `bool`, `int`, `list`), allowed
values, default and help text.

- The wizard (`site/`) renders its form from `options.json` and builds the
  command with a pure function covered by node tests.
- `install.sh` parses the same flags in bash, with no runtime dependency on
  `jq` (a fresh phone doesn't have it).
- A bats contract test walks `options.json` and runs every value through
  `install.sh --dry-run`, failing if the installer rejects anything the
  wizard can emit, or if the plan doesn't reflect it.

## Consequences

- Adding an option means: add it to `options.json`, make the contract test
  pass in `install.sh`, implement it. The wizard picks it up automatically.
- The generated command is plain flags, readable before pasting.
