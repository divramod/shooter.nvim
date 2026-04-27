---
name: refactor-tmux-tools-misc
description: Refactor remaining oversized files (syntax, health, toggle_panes, git_worktree, analytics/data) and address their security findings.
status: approved
phase_id: 004
depends_on: ["000"]
wave: 2
created: 2026-04-26
tier: large
tier_source: deterministic
---

# Phase 004 — Refactor `tmux/`, `tools/`, `analytics/`, root

## Overview

Catch-all phase for the remaining files > 350 LOC plus their security findings:

| file                                  | LOC | likely seam                              |
|---------------------------------------|-----|------------------------------------------|
| `lua/shooter/syntax.lua` (root)       | 513 | per syntax group                         |
| `lua/shooter/tmux/toggle_panes.lua`   | 377 | layout / state / actions                 |
| `lua/shooter/tools/git_worktree.lua`  | 378 | list / create / delete                   |
| `lua/shooter/health.lua` (root)       | 369 | per check section (tmux / claude / hal)  |
| `lua/shooter/help.lua` (root)         | 314 | review-only (already small)              |
| `lua/shooter/analytics/data.lua`      | 313 | parse / aggregate / format               |
| `lua/shooter/core/shotfile_fix.lua`   | 312 | review-only — handled in Phase 002 if scoped, else here |

## Architecture

```
lua/shooter/syntax/
  init.lua                # re-export; keep top-level Highlight set call
  shot_headers.lua        # `## shot N` highlights
  bullets.lua             # bullet-system highlights
  links.lua               # link highlights
  meta.lua                # metaplan-specific highlights

lua/shooter/tmux/toggle_panes/
  init.lua
  layout.lua
  state.lua
  actions.lua

lua/shooter/tools/git_worktree/
  init.lua
  list.lua
  create.lua
  delete.lua

lua/shooter/health/
  init.lua                # health.check entry
  tmux.lua
  claude.lua
  hal.lua
  shotfile.lua

lua/shooter/analytics/data/
  init.lua
  parse.lua
  aggregate.lua
  format.lua
```

## Approach

1. T001: read each file; produce per-file seam plan.
2. Tests-first per file group (tmux, tools, health, analytics).
3. Splits in any order (no inter-dependencies known).
4. Security fixes: `health.lua` has multiple `io.popen` calls; `tools/git_worktree.lua` shells to git; `tmux/*.lua` shells to tmux extensively. Apply table-form / shellescape / validation per `baseline.md` findings.
5. Verify.

## Tasks

- [x] **T001** — Read & seam-map five files
  - **Acceptance:** `seams.md` lists per-file seam plan for syntax, toggle_panes, git_worktree, health, analytics/data.
  - **Verify:** `phases/004-refactor-tmux-tools-misc/seams.md` exists.
  - **Files:** `docs/plans/0001-feats-refactor/phases/004-refactor-tmux-tools-misc/seams.md`
  - **Size:** L
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T002** — Characterization tests for `syntax.lua` + `analytics/data.lua`
  - **Acceptance:** Both files ≥ 80% coverage.
  - **Verify:** Tests green; coverage report.
  - **Files:** `tests/syntax_spec.lua`, `tests/analytics/data_*_spec.lua`
  - **Size:** M
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T003** — Characterization tests for `health.lua`
  - **Acceptance:** ≥ 80% coverage; checks must `pending()` when their tool is absent (e.g. `tmux -V` failing → skip, not error).
  - **Verify:** Tests green on a minimal env (no tmux); coverage report.
  - **Files:** `tests/health_*_spec.lua`
  - **Size:** M
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T004** — Characterization tests for `tmux/toggle_panes.lua` + `tools/git_worktree.lua`
  - **Acceptance:** ≥ 80% coverage; tests `pending()` outside tmux/git env.
  - **Verify:** Tests green in a minimal env; coverage report.
  - **Files:** `tests/tmux/toggle_panes_*_spec.lua`, `tests/tools/git_worktree_*_spec.lua`
  - **Size:** L
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [ ] **T005** — Split `syntax.lua`
  - **Acceptance:** Per T001's seam plan; ≤ 350 LOC per sub-module.
  - **Verify:** `find lua/shooter/syntax -name '*.lua' -exec wc -l {} + | awk '$1>350{exit 1}'`; tests + smoke green.
  - **Files:** `lua/shooter/syntax/*.lua`, `lua/shooter/syntax.lua`
  - **Size:** M
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

- [ ] **T006** — Split `health.lua`
  - **Acceptance:** Per T001's seam plan; ≤ 350 LOC per sub-module; `health.check` entry preserved.
  - **Verify:** `:checkhealth shooter` works; tests + smoke green.
  - **Files:** `lua/shooter/health/*.lua`, `lua/shooter/health.lua`
  - **Size:** M
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

- [ ] **T007** — Split `tmux/toggle_panes.lua` + `tools/git_worktree.lua` + `analytics/data.lua`
  - **Acceptance:** All three split per T001; each sub-module ≤ 350 LOC.
  - **Verify:** Aggregate `find … -exec wc -l {} +`; tests + smoke green.
  - **Files:** `lua/shooter/tmux/toggle_panes/*.lua`, `lua/shooter/tools/git_worktree/*.lua`, `lua/shooter/analytics/data/*.lua`, plus shims
  - **Size:** L
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

- [ ] **T008** — Tmux/tools/health/analytics/root security fixes
  - **Acceptance:** Every Phase-004-area finding from `baseline.md` fixed or deferred. Specific known sites:
    - `lua/shooter/health.lua:87,111,226` — `io.popen` with interpolation; replace with table-form `vim.fn.system`.
    - `lua/shooter/tools/git_worktree.lua` — git shell-outs; table-form.
    - `lua/shooter/tools/tmux_panes.lua:6` — `vim.fn.systemlist(cmd)` with cmd from caller; verify caller-side sanitization.
    - `lua/shooter/syntax.lua:296` — `vim.fn.systemlist('git rev-parse …')`; table-form.
  - **Verify:** Targeted security tests; grep confirms no string-form interpolation in the touched files.
  - **Files:** Listed sites + `tests/security/area_004_spec.lua`
  - **Size:** L
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

- [ ] **T009** — Verify final state
  - **Acceptance:** Suite green; smoke loader green; coverage of touched files ≥ 80%.
  - **Verify:** As prior phases.
  - **Files:** —
  - **Size:** S
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

## Risks

- Health checks are interactive-only meaningful; tests can verify the *check function structure* (does it call `vim.health.ok`/`vim.health.warn`) but not the *result*. Acceptable as long as code paths run.
- `tools/git_worktree.lua` mutates the real git state if not carefully isolated. Tests must use `git init`'d tmpdirs.

## Open Questions

1. `help.lua` (314 LOC) is just under the 350 cap. Audit only, no split. Confirm in T001's read.
2. `core/shotfile_fix.lua` (312 LOC) likewise. Document review outcome in T001.
