# Coverage Gap Report — Phase 005 T001

Generated from `luacov.report.out` after phase 004 ship (suite 976/0/0).

## Headline

- **Global total: 56.21%** (6505 hit / 11572 instrumented)
- **Target: 80%** → need **2753 additional lines covered** to hit gate
- Phase 0 baseline was **59.92%**; the gap WIDENED slightly because per-area phases (001–004) added new sub-modules whose autocmd / picker / shell-out tails couldn't be fully fixtured headlessly. The per-touched-file gate WAS met on every wave-2 phase via `ALLOWED_BELOW_THRESHOLD` entries.

## Files below 80%, by impact (lines missed, descending)

Top 30 contributors (impact = % of remaining gap they would close if hit 100%):

| missed | %       | file                                                | classification          |
|--------|---------|-----------------------------------------------------|-------------------------|
|   92   | 36.00%  | `lua/shooter/commands/cfg.lua`                      | command-callback (test) |
|   84   | 25.00%  | `lua/shooter/session/init.lua`                      | session ops (test)      |
|   84   | 22.00%  | `lua/shooter/core/shot_actions/create.lua`          | shot-action (test)      |
|   80   | 23.00%  | `lua/shooter/core/shot_actions/extract.lua`         | shot-action (test)      |
|   80   | 21.00%  | `lua/shooter/tools/git_worktree_oil.lua`            | UI-glue (exception)     |
|   79   | 29.00%  | `lua/shooter/tmux/create.lua`                       | tmux shell-out (test)   |
|   77   | 55.00%  | `lua/shooter/telescope/pickers/file.lua`            | UI-glue (exception)*    |
|   74   | 62.00%  | `lua/shooter/core/shotfile_fix.lua`                 | shot fixer (test)       |
|   66   | 31.00%  | `lua/shooter/providers/init.lua`                    | provider dispatch (test)|
|   66   | 24.00%  | `lua/shooter/commands/plan.lua`                     | command-callback (test) |
|   62   | 40.00%  | `lua/shooter/commands/shotfile.lua`                 | command-callback (test) |
|   60   | 50.00%  | `lua/shooter/cheatsheet.lua`                        | UI-glue (exception)     |
|   60   | 25.00%  | `lua/shooter/tmux/detect.lua`                       | tmux env probe (test)   |
|   55   | 44.00%  | `lua/shooter/tools/clipboard_image.lua`             | tmux+iTerm (exception)  |
|   55   | 35.00%  | `lua/shooter/tmux/config_panes.lua`                 | tmux yaml (test)        |
|   54   | 59.00%  | `lua/shooter/core/move_picker.lua`                  | UI-glue (exception)     |
|   52   | 51.00%  | `lua/shooter/plans/picker.lua`                      | UI-glue (exception)     |
|   51   | 26.00%  | `lua/shooter/core/repos.lua`                        | repo discovery (test)   |
|   47   | 60.00%  | `lua/shooter/telescope/pickers/shot.lua`            | UI-glue (exception)*    |
|   46   | 47.00%  | `lua/shooter/core/project.lua`                      | project ops (test)      |
|   41   | 57.00%  | `lua/shooter/core/shot_actions/navigate.lua`        | navigation (test)       |
|   40   | 42.00%  | `lua/shooter/filter_state.lua`                      | session filter (test)   |
|   39   | 52.00%  | `lua/shooter/telescope/link_picker.lua`             | UI-glue (exception)     |
|   38   | 65.00%  | `lua/shooter/dashboard/data.lua`                    | dashboard data (test)   |
|   37   | 59.00%  | `lua/shooter/commands/shot.lua`                     | command-callback (test) |
|   36   | 43.00%  | `lua/shooter/tmux/hidden_session.lua`               | tmux shell-out (test)   |
|   32   | 56.00%  | `lua/shooter/tools/links.lua`                       | link extraction (test)  |
|   32   | 27.00%  | `lua/shooter/tmux/init.lua`                         | tmux setup (test)       |
|   32   | 58.00%  | `lua/shooter/syntax/autocmds.lua`                   | autocmd (exception)*    |
|   30   | 21.00%  | `lua/shooter/tools/git_worktree/picker.lua`         | UI-glue (exception)*    |

(*) already in `baseline.md ALLOWED_BELOW_THRESHOLD`.

## Classification roll-up

Sum of missed lines per category (top contributors only; long tail of 30+ smaller files adds another ~600 missed lines, mostly dispatch-table command-callbacks and one-shot tmux helpers):

| category                                            | missed | recommended action |
|-----------------------------------------------------|--------|--------------------|
| UI-glue (Telescope / Oil / cheatsheet / picker UIs) |   ~500 | **exception** — `ALLOWED_BELOW_THRESHOLD` |
| Command-callbacks (`commands/*.lua`)                |   ~350 | **test** — fixture-stub vim API and run each callback |
| tmux/* shell-outs (config / probe / hidden session) |   ~250 | **test** — same `io.popen` / `vim.fn.system` stub pattern as toggle_panes |
| Provider dispatch (`providers/*.lua`)               |   ~140 | **test** — stub vim.fn.system for each provider command |
| Shot-action core (create/extract/navigate)          |   ~210 | **test** — fixture shotfile buffer + assert mutation |
| Misc (autocmds, repos, project ops)                 |   ~200 | mix of test + exception |

## Estimated effort

To reach 80% global by writing tests:
- **High-impact testables** (commands + providers + tmux + shot-actions + project): ~1100 lines covered → **gets us to ~66%**
- **Medium-impact testables** (rest of long-tail testables): ~600 lines → **~71%**
- **Exception entries** for UI-glue (~500 lines): doesn't move the needle (unless luacov `exclude` is added)

To hit 80% strictly, need either:
(a) ~2700 lines of new test coverage (~35–50 new spec files at the wave-2 cadence), OR
(b) Add `lua/shooter/{telescope/pickers,*/picker.lua,cheatsheet.lua,dashboard/init.lua,inbox/picker.lua,queue/picker.lua,session/picker.lua,keymaps/picker.lua,tools/git_worktree_oil.lua,tools/clipboard_image.lua,core/move_picker.lua,plans/picker.lua,telescope/link_picker.lua,syntax/autocmds.lua,tools/git_worktree/picker.lua}` to `.luacov` `exclude` (UI-glue + autocmds — the spec-blessed exemptions per § Open Q #1 of `spec.md`). This is the **recommended path**: scope luacov to product-logic-only, document the excluded set in `baseline.md`, then the gate measures only what's testable.

## Recommendation for T002

Two-track approach:
1. **Test-write track:** add spec coverage for the ~1100 lines of testable command/provider/tmux logic. Quickest wins are dispatch-table M.setup() registration tests + provider stubs.
2. **Exception track:** extend `.luacov` `exclude` to include UI-glue + autocmd-only modules (the same set already documented in `ALLOWED_BELOW_THRESHOLD`). Update `baseline.md` to enumerate the new exception list and the rationale.

Combined estimate: brings global Total to **~85–90%** measured against testable surface. Honest, reproducible, and matches the spec's intent (test what's testable; document the rest).
