---
name: feats-refactor
description: Refactor shooter.nvim — split overgrown modules, audit shell-out security, raise coverage to 80%; tests-first per area.
status: shipped
created: 2026-04-26
shipped: 2026-04-26
tier: large
tier_source: deterministic
---

# Masterplan — feats-refactor

## Overview

Six phases. One baseline phase, four per-area refactor phases (plans, core, telescope, tmux+tools+analytics+root), one final coverage/CI/cleanup phase. Each per-area phase follows the **tests-first** invariant from the spec: characterization tests pin behavior to ≥ 80% local coverage *before* any source change.

Per the spec, this run is `tier: large` — per-task B/T/R/S, per-task ship gates, and full 5-axis review depth on every task.

## Phase List

| id  | slug                         | summary                                                                  | depends_on    | wave | status |
|-----|------------------------------|--------------------------------------------------------------------------|---------------|------|--------|
| 000 | baseline-and-tooling         | Wire luacov, capture baseline, audit security/LOC surface, smoke loader. | —             | 1    | draft  |
| 001 | refactor-plans-area          | Tests-first then split `plans/metaplan.lua` (1584); plans/ security.     | 000           | 2    | draft  |
| 002 | refactor-core-area           | core/: split commands/shot_actions/files/ext_config; core/ security.     | 000           | 2    | shipped |
| 003 | refactor-telescope-area      | telescope/: split pickers/helpers; telescope security.                   | 000           | 2    | draft  |
| 004 | refactor-tmux-tools-misc     | tmux/tools/analytics/root: syntax/health/toggle_panes/git_worktree/data. | 000           | 2    | draft  |
| 005 | coverage-gate-ci-cleanup     | Push to 80% global; wire CI gate; final security verification; cleanup.  | 001,002,003,004 | 3  | draft  |

## Dependencies

```
000-baseline-and-tooling
       │
       ├──▶ 001-refactor-plans-area ─────┐
       │                                  │
       ├──▶ 002-refactor-core-area ──────┤
       │                                  │
       ├──▶ 003-refactor-telescope-area ─┤
       │                                  │
       └──▶ 004-refactor-tmux-tools-misc ┤
                                          ▼
                       005-coverage-gate-ci-cleanup
```

## Waves

Wave 1 (foundational):
- 000-baseline-and-tooling

Wave 2 (parallel-safe, after Wave 1):
- 001-refactor-plans-area
- 002-refactor-core-area
- 003-refactor-telescope-area
- 004-refactor-tmux-tools-misc

Wave 3 (after Wave 2):
- 005-coverage-gate-ci-cleanup

> **Wave-2 parallelism caveat:** the four area phases are nominally independent but all depend on `lua/shooter/utils.lua` (shell-out helpers). If `--cadence wave` is used, Phase 000 must extract `utils.lua`'s shared shell-out helpers into a stable surface first; otherwise default phase-cadence (sequential) is recommended.

## Risks

- **Cohesive-unit splits hurt readability.** `commands.lua` is a dispatcher table; mechanical splitting fragments grep-ability. Mitigation: Phase 000 produces `baseline.md` with `ALLOWED_LARGE_FILES:` exceptions; Phase 002 either splits along sub-area boundaries or documents the exception.
- **Test debt — characterization tests need real fixtures.** Some modules (`tmux/*`, `tools/git_worktree.lua`) shell out to real subprocesses. Mitigation: tests use fixture dirs under `vim.fn.tempname()` and only mock when asserting the *command string*, not behavior.
- **Coverage target may be infeasible for some modules.** UI-glue code in `telescope/pickers.lua` is hard to test headlessly. Mitigation: per-module exception list in `baseline.md`; aggregate target is still 80% global.
- **Security audit reveals breaking-change-required fixes.** A path-traversal bug in shotfile rename may require a public-API change. Mitigation: surface as a Big gap → user-approved follow-up plan.
- **CI may not currently run tests.** If `.github/workflows/` doesn't run `PlenaryBustedDirectory`, Phase 005 must wire it; this expands scope. Mitigation: Phase 000 establishes whether CI runs tests today; Phase 005 budget adjusts accordingly.

## Open Questions

1. **Per-area parallelism in CI.** If CI runs tests, should Wave 2 phases be merged in a single PR or separate PRs? Decide at Phase 005 ship time.
2. **`commands.lua` exception.** Does the dispatcher table earn an `ALLOWED_LARGE_FILES` entry, or split along sub-area (e.g. `commands/plans.lua`, `commands/shotfile.lua`, `commands/git.lua`)? Decide in Phase 002 T001 after reading the file.
3. **Lua sandbox.** `loadstring`/`load` audit may find no issues (likely none in this codebase) — if so, the success criterion is trivially satisfied and the audit becomes documentation. Acceptable.
