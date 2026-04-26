---
name: baseline-and-tooling
description: Wire luacov, capture baseline coverage, audit security/LOC surface, write smoke-require loader.
status: shipped
phase_id: 000
depends_on: []
wave: 1
created: 2026-04-26
tier: large
tier_source: deterministic
---

# Phase 000 — Baseline & Tooling

## Overview

Foundation phase. No source-code logic changes. Produces the artifacts the per-area refactor phases consume: coverage baseline, security inventory, LOC inventory, smoke-require enumeration, and CI test-run verification.

## Architecture

- `tests/minimal_init.lua` gains a luacov auto-install block (mirroring the existing plenary bootstrap) plus an idempotent `require('luacov')` call before `set rtp+=.`.
- A new `docs/plans/0001-feats-refactor/baseline.md` captures: total LOC, per-file LOC, per-module coverage %, total coverage %, every shell-out / path-handling / dynamic-exec / tempfile / file-perm site, and the `ALLOWED_LARGE_FILES:` exception list.
- A new `docs/plans/0001-feats-refactor/scripts/smoke_require.lua` enumerates every `require('shooter.<path>')` callable on a fresh Neovim and asserts each loads. Used by Success Criterion #6.
- A new `.luacov` config file pins coverage scope to `lua/shooter/**` and excludes `tests/**`.

## Approach

1. Verify CI state first (does it run tests today?). Determines Phase 005 budget.
2. Wire luacov with auto-install, gated by an idempotency check (skip if present).
3. Run baseline coverage; capture % per module + total.
4. Run all security-audit greps and inventory the findings (catalogue only, no fixes — fixes belong to area phases).
5. Walk `lua/` for files > 350 LOC; classify each as **split-candidate** or **exception**; populate `ALLOWED_LARGE_FILES:` in `baseline.md` for exceptions only.
6. Generate `smoke_require.lua` from a recursive walk of `lua/shooter/**/*.lua`.
7. Run the success-criteria suite (`hal lifecycle masterplan ship --dry-run` equivalent) to confirm the harness works end-to-end with placeholder/early values.

## Tasks

- [x] **T001** — Verify CI test-run state
  - **Acceptance:** `baseline.md § CI` records whether `.github/workflows/` runs `PlenaryBustedDirectory` today; if no, lists workflow file(s) that need wiring in Phase 005.
  - **Verify:** `grep -rE "PlenaryBustedDirectory|busted" .github/workflows/ ; echo $?` — outcome documented in baseline.md.
  - **Files:** `.github/workflows/*.yml` (read), `docs/plans/0001-feats-refactor/baseline.md`
  - **Size:** S
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T002** — Wire luacov auto-install in `tests/minimal_init.lua`
  - **Acceptance:** Running tests installs luacov on first invocation if absent; subsequent invocations skip install. `require('luacov')` runs before `set rtp+=.`. A new `.luacov` config scopes coverage to `lua/shooter/**`.
  - **Verify:** `rm -rf /tmp/nvim/site/pack/packer/start/luacov; nvim --headless -u tests/minimal_init.lua -c "lua print(pcall(require,'luacov'))" -c "qa!" 2>&1 | grep -q "true"`
  - **Files:** `tests/minimal_init.lua`, `.luacov`
  - **Size:** M
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T003** — Capture coverage baseline
  - **Acceptance:** Full test suite runs under luacov; `luacov.report.out` generated; per-module + total % copied into `baseline.md § Coverage Baseline`.
  - **Verify:** `test -s luacov.report.out && grep -E '^Total' luacov.report.out`
  - **Files:** `docs/plans/0001-feats-refactor/baseline.md`, generated `luacov.report.out`
  - **Size:** S
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T004** — Security-audit inventory
  - **Acceptance:** `baseline.md § Security Inventory` lists every site for: shell-outs (`vim.fn.system`/`systemlist`/`io.popen`/`jobstart`), path-traversal-prone interpolation, `loadstring`/`load`/`dofile`/`loadfile`, `vim.fn.tempname`/`os.tmpname`/`/tmp/` writes, file-mode setters. Each entry: file:line, kind, risk-class (high/med/low), notes.
  - **Verify:** `awk '/^## Security Inventory/{flag=1; next} /^## /{flag=0} flag' docs/plans/0001-feats-refactor/baseline.md | grep -cE ':[0-9]+'` — non-zero count.
  - **Files:** `docs/plans/0001-feats-refactor/baseline.md`
  - **Size:** L
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T005** — LOC inventory and exception list
  - **Acceptance:** `baseline.md § LOC Inventory` lists every file > 350 LOC with kind (`split-candidate` or `exception`). Exceptions populate `ALLOWED_LARGE_FILES:` with rationale.
  - **Verify:** `find lua -name '*.lua' -exec wc -l {} + | awk '$1 > 350 && $2 != "total" {print $2}' | while read f; do grep -q "$f" docs/plans/0001-feats-refactor/baseline.md || exit 1; done`
  - **Files:** `docs/plans/0001-feats-refactor/baseline.md`
  - **Size:** M
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T006** — Smoke-require enumerator
  - **Acceptance:** `scripts/smoke_require.lua` enumerates every `lua/shooter/**/*.lua` as a require path and asserts each loads on a fresh Neovim.
  - **Verify:** `nvim --headless -u tests/minimal_init.lua -c "luafile docs/plans/0001-feats-refactor/scripts/smoke_require.lua" -c "qa!" 2>&1 | grep -E "^OK |^FAIL " | tee /tmp/smoke.log; ! grep -q "^FAIL " /tmp/smoke.log`
  - **Files:** `docs/plans/0001-feats-refactor/scripts/smoke_require.lua`
  - **Size:** M
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

## Risks

- luacov via luarocks-style bootstrap may need `luarocks` itself — fallback: clone `keplerproject/luacov` into `/tmp/nvim/site/pack/packer/start/luacov` like plenary, then `require` directly.
- Smoke-require loader will surface latent require errors (modules that load successfully today only because nothing imports them in the test path). Treat surfaced errors as small gaps; fix in Phase 000 only if trivial, else big gap.

## Open Questions

1. If a module fails the smoke loader today (pre-existing bug), does Phase 000 fix it or punt to a gap? Default: punt; phase 000 is observation-only.
