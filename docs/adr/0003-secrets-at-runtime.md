# 0003 — Secrets are supplied at install time, never committed

**Status:** Accepted, 2026-10-01

## Context

The repo is public. Setting up the owner's phone needs private values: a
NetBird setup key and, less sensitive but still personal, the self-hosted
management URL. A fresh phone should be fully set up from one pasted command.

## Decision

The repo contains no secrets, no personal hostnames and no defaults that
point at private infrastructure. Private values reach the installer in one of
these ways, highest priority first:

1. Environment variables on the command line (`NB_SETUP_KEY=… bash install.sh`).
2. `--private <source>`: a local file, or an `https://` link the owner
   controls (e.g. a secret gist). The content is **parsed** as `KEY=VALUE`
   lines against an allow-list (`NB_*`, `TERMINUX_*`). It is never sourced or
   executed, so a tampered link can change settings but cannot run code.
   Plain `http://` is refused.
3. `~/.config/terminux/private.env` (mode 0600) on the phone.
4. A hidden interactive prompt for anything still missing.

The NetBird setup key is used once to enroll and then discarded: it is handed
to `netbird` through a temporary 0600 file (never `argv`, so it doesn't show
in `ps`), deleted immediately, and never written to config.

The wizard on GitHub Pages never asks for secrets. It generates a command
with `--with netbird` and tells the user to add `--private <link>` or answer
the prompt on the phone.

## Consequences

- A leaked private link exposes whatever it contains. Owners should use
  NetBird setup keys with a short expiry and a usage limit of 1, so a link is
  worthless after the phone enrolls.
- Command-line environment variables can land in shell history; the docs
  recommend the prompt or `--private` for keys.
