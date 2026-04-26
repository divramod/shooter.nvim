---
name: refactor-plans-area
description: Tests-first then split lua/shooter/plans/metaplan.lua (1584 LOC); fix plans/-area security findings.
status: shipped
phase_id: 001
depends_on: ["000"]
wave: 2
created: 2026-04-26
tier: large
tier_source: deterministic
---

# Phase 001 — Refactor `plans/` Area

## Overview

The `plans/` area is dominated by `metaplan.lua` (1584 LOC) — by far the worst LOC offender. The file mixes parsing, rendering, category management, numbering, and rename/move ops; each is a clean cohesive unit candidate.

Tests-first: characterize current observable behavior of `metaplan.lua` to ≥ 80% local coverage *before* any source changes. Then split into a sub-module folder. Then apply security fixes flagged for `plans/` in `baseline.md`.

## Architecture

Target layout:

```
lua/shooter/plans/
  init.lua                 # public surface re-exporter (already exists, keep)
  metaplan.lua             # → split (see below); init.lua re-exports
  metaplan/
    init.lua               # re-exports public surface; no logic
    parse.lua              # markdown → AST (categories, plans, notes)
    render.lua             # AST → markdown (preserves notes/parens)
    categories.lua         # in_progress / planned / next plans / backlog / done
    numbering.lua          # NNNN allocation, gap-fill, drift detection
    rename.lua             # plan rename/move ops (security-sensitive)
```

Each sub-module ≤ 350 LOC. `metaplan/init.lua` is re-export only. Existing `require('shooter.plans.metaplan')` callers see no change.

## Approach

1. **Read** `metaplan.lua` end-to-end; identify the natural seams (parse / render / categories / numbering / rename).
2. **Tests-first** — write `_spec.lua` files covering each seam against the current single-file `metaplan.lua`. Coverage of `lua/shooter/plans/**` must reach ≥ 80% before T003 begins.
3. **Split** mechanically along the identified seams. Public surface preserved via `metaplan/init.lua` re-exports.
4. **Security fixes** for plans/ findings (rename ops are highest-risk — path traversal in plan-folder rename).
5. **Re-run** tests + coverage; verify green; verify smoke-require still loads `shooter.plans.metaplan`.

## Tasks

- [x] **T001** — Read & seam-identify `metaplan.lua`
  - **Acceptance:** Phase context updated with the precise function-list per seam (parse / render / categories / numbering / rename); seam plan committed before any test-writing begins.
  - **Verify:** `phases/001-refactor-plans-area/seams.md` exists and lists ≥ 5 seams with function counts.
  - **Files:** `docs/plans/0001-feats-refactor/phases/001-refactor-plans-area/seams.md`
  - **Size:** M
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T002** — Characterization tests for `plans/` (parse + categories)
  - **Acceptance:** `tests/plans/metaplan_parse_spec.lua` + `tests/plans/metaplan_categories_spec.lua` cover parse + category functions; combined module coverage for those functions ≥ 80%.
  - **Verify:** Test files run green; `luacov.report.out` shows ≥ 80% on parse + categories sections.
  - **Files:** `tests/plans/metaplan_parse_spec.lua`, `tests/plans/metaplan_categories_spec.lua`
  - **Size:** L
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T003** — Characterization tests for `plans/` (render + numbering + rename)
  - **Acceptance:** Three additional `_spec.lua` files covering render, numbering, rename. Total `plans/` coverage ≥ 80%.
  - **Verify:** Test files green; aggregate `lua/shooter/plans/**` coverage ≥ 80% in `luacov.report.out`.
  - **Files:** `tests/plans/metaplan_render_spec.lua`, `tests/plans/metaplan_numbering_spec.lua`, `tests/plans/metaplan_rename_spec.lua`
  - **Size:** L
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T004** — Split `metaplan.lua` along identified seams
  - **Acceptance:** `lua/shooter/plans/metaplan/{init,parse,render,categories,numbering,rename}.lua` exist; each ≤ 350 LOC; `lua/shooter/plans/metaplan.lua` either deleted or replaced with `return require('shooter.plans.metaplan.init')` shim. All Phase 000 + Phase 001 tests still green. Smoke loader passes.
  - **Verify:** `find lua/shooter/plans -name '*.lua' -exec wc -l {} + | awk '$1>350{exit 1}'`; tests run green; smoke loader green.
  - **Files:** `lua/shooter/plans/metaplan/*.lua`, `lua/shooter/plans/metaplan.lua`
  - **Size:** XL
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T005** — Plans/-area security fixes
  - **Acceptance:** Every plans/ finding from `baseline.md § Security Inventory` is fixed or explicitly deferred (with rationale). Path-traversal-prone rename ops use canonicalize + reject-`..` checks. Shell-outs use `shellescape` or table-form `vim.fn.system({...})`.
  - **Verify:** `! grep -nE "(vim\.fn\.system|io\.popen)\([\"'].*\.\..*[\"']\)" lua/shooter/plans/`; unit tests for canonicalization in `tests/plans/metaplan_rename_spec.lua` cover `..` rejection; tests green.
  - **Files:** `lua/shooter/plans/metaplan/rename.lua`, possibly `lua/shooter/plans/init.lua`, plus tests
  - **Size:** M
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T006** — Verify final state
  - **Acceptance:** Full test suite green; `lua/shooter/plans/**` coverage ≥ 80%; no public-surface regressions.
  - **Verify:** Full `:PlenaryBustedDirectory tests/` green; smoke loader green; `awk '/^lua\/shooter\/plans/' luacov.report.out` shows ≥ 80%.
  - **Files:** —
  - **Size:** S
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

## Risks

- Sub-modules may have circular deps (e.g. `rename.lua` needs `numbering.lua` which needs `parse.lua`). Mitigation: walk the dep graph in T001; reject cycles by hoisting shared helpers into a `metaplan/util.lua` if needed.
- Existing tests in `tests/plans/` already exist (51 spec files repo-wide; some in `tests/plans/`). New tests should not duplicate; T002/T003 reads existing first.

## Open Questions

1. Does `plans/` have an existing `init.lua` that re-exports `metaplan`? If yes, the shim path is simpler; if no, T004 must create one.
2. Are any sub-modules useful as a public surface (`require('shooter.plans.metaplan.parse')`)? Default: no — keep public surface narrow at `shooter.plans.metaplan`.
