# 0007 — Licence terminux under Apache-2.0

**Status:** Accepted, 2026-10-01 (replaces the MIT licence used in the first
local commits, before anything was published)

## Context

terminux redistributes code from two projects: linux-android (MIT) and
ternux (Apache-2.0). It should stay free for anyone to use, fork and build
on, and its attribution must be legally sound.

| Option | Fit |
|--------|-----|
| MIT | Simple, but the ternux-derived files would stay Apache-2.0, leaving a mixed-licence tree |
| **Apache-2.0** | Accepts both inputs: MIT code may be relicensed as long as its notice is kept, and ternux is already Apache-2.0. Adds an explicit patent grant, and its NOTICE-file convention gives attribution a formal home |
| GPL-3.0 | Would also allow copying termux-proot-script (GPL-3.0), but forces every fork to stay GPL — more restrictive than this project needs |

## Decision

The whole project is licensed under Apache-2.0 (`LICENSE`). Attribution
follows the Apache convention:

- `NOTICE` lists every project whose code is included, with its copyright
  and licence. It must be kept with any redistribution.
- `LICENSES/` holds the upstream licence texts we're obliged to keep (the
  MIT notice for linux-android, ternux's NOTICE).
- Source files carry `SPDX-License-Identifier: Apache-2.0`; files with adapted
  code also name their origin.
- `CREDITS.md` thanks projects that informed terminux without contributing code.

## Consequences

- Code from GPL-licensed projects (termux-proot-script) can't be copied in.
  Re-implementing ideas is fine. If vendoring GPL code ever becomes worth it,
  relicensing to GPL-3.0 is possible, because Apache-2.0 and MIT code may be
  included in a GPL-3.0 work.
- Code from projects with no licence (termux-vscode-x11) can never be copied.
