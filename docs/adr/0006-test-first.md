# 0006 — Features are built test-first with bats

**Status:** Accepted, 2026-10-01

## Context

The installer runs once per phone, takes half an hour, and fails far from
any developer. Regressions like the upstream KDE launcher bug (a literal
`\n` that produced `nexec`) are invisible until someone's desktop doesn't
start.

## Decision

- Every feature and bug fix starts as a failing bats test (red), then the
  minimal code to pass it (green), then cleanup.
- Android-only commands are called through `PATH` so tests can stub them and
  assert on how terminux used them; no test needs a phone.
- The inherited installer gets characterization tests: source it in a
  sandbox, render the launchers, and check the generated scripts (syntax,
  no `\nexec`, KWin settings, X lock cleanup).
- CI runs `bash -n`, shellcheck, bats and the wizard's node tests on every
  push and pull request.

## Consequences

- Some behaviour can still only be proven on a device (GPU, NetBird data
  path). Those gaps are listed in [GALAXY-FOLD.md](../GALAXY-FOLD.md) and the
  ADRs rather than hidden.
