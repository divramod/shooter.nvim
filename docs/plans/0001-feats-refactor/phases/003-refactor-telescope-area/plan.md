---
name: refactor-telescope-area
description: telescope/ refactor — split pickers.lua (620), helpers.lua (529); telescope path-handling security.
status: approved
phase_id: 003
depends_on: ["000"]
wave: 2
created: 2026-04-26
tier: large
tier_source: deterministic
---

# Phase 003 — Refactor `telescope/` Area

## Overview

Two split candidates: `lua/shooter/telescope/pickers.lua` (620 LOC) and `lua/shooter/telescope/helpers.lua` (529 LOC). Telescope is UI-glue code, so coverage is harder; the spec explicitly tolerates per-module coverage exceptions when a UI module is genuinely test-resistant — but only after a sincere effort.

## Architecture

```
lua/shooter/telescope/
  pickers/
    init.lua             # re-export
    shotfile.lua         # shotfile picker
    plan.lua             # plan picker
    link.lua             # tmux link picker
    project.lua          # project picker
    cli.lua              # cli/tool picker
  helpers/
    init.lua             # re-export
    sorter.lua           # age-based, alpha tiebreak
    filter.lua           # path filtering
    format.lua           # entry display formatting
    icon.lua             # nerd-font filetype icons
```

Both `pickers/init.lua` and `helpers/init.lua` are re-export only.

## Approach

1. Read both files; produce seam plan in T001.
2. Tests-first — characterization for both; pure helpers (sorter, filter, format) testable headlessly. Pickers themselves harder; mock `telescope.builtin` calls and assert entry shape.
3. Split per seam plan.
4. Telescope-area security fixes — path-handling in entry-resolution (`require('shooter.telescope.helpers').open_entry`).
5. Verify.

## Tasks

- [ ] **T001** — Read & seam-map `pickers.lua` + `helpers.lua`
  - **Acceptance:** `seams.md` lists per-file seam plan.
  - **Verify:** `phases/003-refactor-telescope-area/seams.md` exists.
  - **Files:** `docs/plans/0001-feats-refactor/phases/003-refactor-telescope-area/seams.md`
  - **Size:** M
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

- [ ] **T002** — Characterization tests for `helpers.lua` pure functions
  - **Acceptance:** Sorter, filter, format, icon: combined ≥ 80% coverage.
  - **Verify:** Tests green; relevant lines in `luacov.report.out` ≥ 80%.
  - **Files:** `tests/telescope/helpers_*_spec.lua`
  - **Size:** L
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

- [ ] **T003** — Characterization tests for `pickers.lua`
  - **Acceptance:** Picker construction tested by stubbing telescope and asserting entry shape; coverage ≥ 80% if achievable, else exception logged in `baseline.md` with rationale.
  - **Verify:** Tests green; coverage report or exception entry.
  - **Files:** `tests/telescope/pickers_*_spec.lua`, possibly `docs/plans/0001-feats-refactor/baseline.md`
  - **Size:** L
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

- [ ] **T004** — Split `helpers.lua`
  - **Acceptance:** Per T001's seam plan; ≤ 350 LOC per sub-module.
  - **Verify:** `find lua/shooter/telescope/helpers -name '*.lua' -exec wc -l {} + | awk '$1>350{exit 1}'`; tests + smoke green.
  - **Files:** `lua/shooter/telescope/helpers/*.lua`, `lua/shooter/telescope/helpers.lua`
  - **Size:** M
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

- [ ] **T005** — Split `pickers.lua`
  - **Acceptance:** Per T001's seam plan; ≤ 350 LOC per sub-module.
  - **Verify:** `find lua/shooter/telescope/pickers -name '*.lua' -exec wc -l {} + | awk '$1>350{exit 1}'`; tests + smoke green.
  - **Files:** `lua/shooter/telescope/pickers/*.lua`, `lua/shooter/telescope/pickers.lua`
  - **Size:** M
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

- [ ] **T006** — Telescope-area security fixes
  - **Acceptance:** Entry-resolution path-handling validates and canonicalizes; no path-traversal via crafted entry input.
  - **Verify:** `tests/telescope/security_spec.lua` covers `..`-rejection and absolute-path-validation in entry open ops.
  - **Files:** `lua/shooter/telescope/helpers/*.lua`, `tests/telescope/security_spec.lua`
  - **Size:** S
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

- [ ] **T007** — Verify final state
  - **Acceptance:** Suite green; smoke loader green; coverage of `lua/shooter/telescope/**` ≥ 80% (or documented exception).
  - **Verify:** As Phase 002 T009.
  - **Files:** —
  - **Size:** S
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

## Risks

- Telescope's API can change between versions; tests pinned to current telescope.nvim API. Mitigation: tests stub the small surface used (`pickers.new`, `finders.new_table`, `actions.select_default`), not the whole library.
- Pickers depend on user theme/colorscheme; entry display is mostly visual — coverage of display functions can be high but the visual outcome isn't asserted. Acceptable.

## Open Questions

1. If `pickers.lua` cannot reach 80% headlessly, what's the agreed exception rationale? Default: cite "UI-glue requires interactive Neovim" in `baseline.md`.
