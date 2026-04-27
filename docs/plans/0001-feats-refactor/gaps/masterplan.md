---
name: feats-refactor-gaps
description: Big gaps surfaced during automode of phase 002. Routed to phase 005 (coverage-gate-ci-cleanup) per masterplan.md.
status: draft
created: 2026-04-27
parent: 0001-feats-refactor
---

# Gaps masterplan — feats-refactor

Big gaps discovered during automode that are out of scope for the
discovering task but in scope for the masterplan as a whole. Phase 005
is the natural home for these.

## G001 — core/+commands coverage gate (Phase 002 T009)

**Discovered by:** Phase 002 T009 verification.

**Acceptance contract:** `coverage of lua/shooter/core/** + lua/shooter/commands* ≥ 80%`.

**Current state (post-002 ship):**

| scope                    | hit/total      | %      |
|--------------------------|----------------|--------|
| `lua/shooter/core/**`    | 1402 / 2302    | 60.90% |
| `lua/shooter/commands/*` |  325 /  813    | 39.98% |

**Why a Big gap, not a small inline:**

1. **Commands sub-modules are inherently low-coverage in unit tests.** Each
   `commands/<area>.lua` is mostly `create_cmd(name, function() …end, opts)`
   blocks. The outer registration loop is exercised by
   `tests/commands_registration_spec.lua` (every name is asserted to be
   registered) but the inner closure bodies require live buffer/UI/tmux
   state and are not normally exercised in unit tests. Closing this gate
   requires a new test category (UI-driven or command-runner harness), not
   an additional `_spec.lua` written in the existing style.
2. **Several core/ modules carry pre-existing low coverage that was
   established before plan 0001 began.** A baseline snapshot from phase
   000 showed e.g. `core/project.lua 47%, core/rename.lua 40%,
   core/repos.lua 26%, core/move_picker 59%, plans/picker 51%`. These
   were not regressed by phase 002 — they were the reason phase 005
   exists.

**Per-file low spots in scope of T009:**

| file                                           | %     | notes                                              |
|------------------------------------------------|-------|----------------------------------------------------|
| `lua/shooter/core/project.lua`                 | 47.13 | list_projects + helpers; pre-existing                |
| `lua/shooter/core/rename.lua`                  | 40.43 | rename helper; pre-existing                          |
| `lua/shooter/core/repos.lua`                   | 26.09 | repo picker integration; pre-existing                |
| `lua/shooter/core/move_picker.lua`             | 59.09 | telescope-driven picker; partial                      |
| `lua/shooter/core/shot_actions/create.lua`     | 22.22 | tmux-driven create_shot_from_claude path uncovered    |
| `lua/shooter/core/shot_actions/extract.lua`    | 23.08 | UI-state-heavy extract paths uncovered                |
| `lua/shooter/core/shot_actions/navigate.lua`   | 57.29 | navigation across open/sent shots                     |
| `lua/shooter/core/shot_actions/info.lua`       | 30.77 | file_stats: pre-existing empty body                   |
| `lua/shooter/core/shots.lua`                   | 52.07 | multiple low-touched helpers                          |
| `lua/shooter/commands/utility.lua`             | 18.94 | merge-into picker + link picker bodies                |
| `lua/shooter/commands/cfg.lua`                 | 36.11 | config edit command bodies                            |
| `lua/shooter/commands/plan.lua`                | 24.14 | plan command bodies                                   |
| `lua/shooter/commands/shotfile.lua`            | 40.95 | shotfile command bodies                               |
| `lua/shooter/commands/shot.lua`                | 59.34 | shot command bodies                                   |

**Disposition:** route to phase 005 (`coverage-gate-ci-cleanup`). That
phase's existing scope ("Push to 80% global; wire CI gate") is exactly
this work. Phase 005 should:

1. Decide per-file: write `_spec.lua` to cover the remaining helpers
   OR add an exception entry to `baseline.md`'s `ALLOWED_LOW_COVERAGE`
   list with rationale.
2. For commands/* sub-modules, decide whether to add `ALLOWED_LOW_COVERAGE`
   for command-body closures (preferred — the registration spec already
   enforces drift-free name binding) OR introduce a UI-test harness.
3. Re-run `awk '/lua\/shooter\/(core|commands)/' luacov.report.out`
   gate; either the threshold is met or the exception list documents
   the deviation.

**No regression introduced:** T005 / T006 / T007 each preserved the
public surface of their split target. T008 added strictly safer code
paths (vim.fn.readdir, argv-form system, regex-validated pane id).
The coverage shortfall is a property of pre-existing code + the
inherent structure of UI-glue code, not of the phase-002 refactor.
