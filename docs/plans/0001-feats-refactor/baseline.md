# Baseline — feats-refactor (plan 0001)

Living document captured during Phase 000. Sections are filled in by Phase 000 tasks T001–T006.

## CI

**Source:** `.github/workflows/test.yml` (Phase 000 T001).

**Status:** CI **does** run tests on push and pull-request to `main` / `master`.

Salient details:

- Trigger: `push` / `pull_request` on `main` and `master`.
- Concurrency group cancels in-progress runs for the same ref.
- Matrix: Neovim `stable` and `nightly` (Ubuntu).
- Test runner: `plenary.test_harness.test_directory('tests/', {minimal_init = 'tests/minimal_init.lua', sequential = true})` (timeout 120s).
- Failure detection: greps test output for `^Failed :.*[1-9]` (Neovim's exit code is unreliable in headless).
- Linter: `luacheck` runs *after* tests with `continue-on-error: true` (advisory only — does not fail the build).

**Implications for Phase 005 (CI gate):**

- CI infrastructure is in place; T004 of Phase 005 only needs to add a coverage step + gate, not bootstrap a workflow.
- The test step already uses `sequential = true` — compatible with luacov's single-process expectation.
- The matrix runs Neovim stable + nightly. The luacov coverage gate should run on **stable only** to avoid double-counting and to keep the canonical baseline reproducible.
- `luacheck` is opportunistic; not in scope to make it strict in this plan, but flag for future hardening.

**No workflow changes required in Phase 000.** Phase 005 T004 will add a coverage step + gate.

## Coverage Baseline

**Source:** `luacov.report.out` (Phase 000 T003).

**Total coverage: 59.92%** (3995 hit / 6667 total lines instrumented in `lua/shooter/`).

**Test suite status:** 50 spec files; all green (no `Failed:` or `Errors:` lines in run log).

**Target:** 80% absolute (per spec). Gap: **20.08 pp**.

### Lowest-coverage files (priority for new tests)

| coverage | file                                               | hit / missed |
|----------|----------------------------------------------------|--------------|
|   0.71%  | `lua/shooter/telescope/helpers.lua`                | 2 / 281      |
|   1.74%  | `lua/shooter/telescope/toggle_panes_picker.lua`    | 2 / 113      |
|   6.90%  | `lua/shooter/tools/response_viewer/claude.lua`     | 4 / 54       |
|   7.78%  | `lua/shooter/tmux/operations.lua`                  | 13 / 154     |
|   9.38%  | `lua/shooter/tmux/keys.lua`                        | 3 / 29       |
|  12.62%  | `lua/shooter/tmux/send.lua`                        | 13 / 90      |
|  14.63%  | `lua/shooter/tmux/shell.lua`                       | 6 / 35       |
|  16.07%  | `lua/shooter/tmux/messages.lua`                    | 9 / 47       |
|  21.13%  | `lua/shooter/tmux/toggle_panes.lua`                | 30 / 112     |
|  21.57%  | `lua/shooter/tools/git_worktree_oil.lua`           | 22 / 80      |

### Highest-coverage files (already in good shape; sentinel reference)

- `lua/shooter/telescope/recency.lua` — **100.00%** (38/38)
- `lua/shooter/analytics/report.lua` — **98.80%** (82/83)
- `lua/shooter/core/fix_titles.lua` — **97.73%** (86/88)
- `lua/shooter/tools/response_viewer/opencode.lua` — **94.79%** (91/96)
- `lua/shooter/core/git_push.lua` — **93.10%** (81/87)

### Implications for per-area phases

- **`telescope/helpers.lua` (0.71%)** is also a Phase 003 split-target. Phase 003's tests-first task gets the 80%-local-coverage gate; this is where most of the 20pp global lift will come from (the file is 281 missed lines).
- **`tmux/*` modules (7-21%)** drag global down by ~5-7pp. These mostly shell out to tmux; without a live tmux, they're hard to characterize. Phase 004 must either pin behavior with `pending()` guards on tmux-required tests, or accept a per-module exception in `ALLOWED_LARGE_FILES:`.
- **`tools/response_viewer/claude.lua` (6.9%)** is small (54 missed) and a quick win — likely UI scaffolding without much logic. Targetable in Phase 004 or Phase 005.

### Coverage report archive

The full `luacov.report.out` from baseline run is committed at `docs/plans/0001-feats-refactor/baseline-coverage.txt` for reproducibility.

## Security Inventory

> Filled in by Phase 000 T004. Will contain a line-by-line catalogue of:
>
> - Shell-out sites: `vim.fn.system`, `vim.fn.systemlist`, `io.popen`, `vim.fn.jobstart`
> - Path-handling sites: file/dir rename/move, untrusted path interpolation
> - Dynamic code execution: `loadstring`, `load(`, `dofile`, `loadfile`
> - Temp-file handling: `vim.fn.tempname`, `os.tmpname`, `/tmp/` writes
> - File-permission setters
>
> Format per row: `<file>:<line> | <kind> | <risk: high|med|low> | <notes>`.

## LOC Inventory

**Source:** `find lua -name '*.lua' -exec wc -l {} +` (Phase 000 T005).

**Soft cap:** 350 LOC. Files over the cap must be split unless listed in `ALLOWED_LARGE_FILES:` below with rationale.

| LOC  | path                                          | kind             | phase | notes                                                              |
|------|-----------------------------------------------|------------------|-------|--------------------------------------------------------------------|
| 1584 | lua/shooter/plans/metaplan.lua                | split-candidate  | 001   | top offender — clear seams (parse/render/categories/numbering/rename) |
| 1190 | lua/shooter/commands.lua                      | split-candidate? | 002   | dispatcher — Phase 002 T006 decides split vs. exception            |
|  795 | lua/shooter/core/shot_actions.lua             | split-candidate  | 002   | per action class                                                   |
|  620 | lua/shooter/telescope/pickers.lua             | split-candidate  | 003   | per picker (shotfile/plan/link/project/cli)                        |
|  529 | lua/shooter/telescope/helpers.lua             | split-candidate  | 003   | sorter/filter/format/icon — also coverage anchor (0.71% baseline)  |
|  513 | lua/shooter/syntax.lua                        | split-candidate  | 004   | per syntax group                                                   |
|  456 | lua/shooter/core/files.lua                    | split-candidate  | 002   | git-detect / path-ops / repo-walk                                  |
|  416 | lua/shooter/core/ext_config.lua               | split-candidate  | 002   | parse / validate / merge                                           |
|  378 | lua/shooter/tools/git_worktree.lua            | split-candidate  | 004   | list / create / delete                                             |
|  377 | lua/shooter/tmux/toggle_panes.lua             | split-candidate  | 004   | layout / state / actions                                           |
|  369 | lua/shooter/health.lua                        | split-candidate  | 004   | per-check section (tmux/claude/hal/shotfile)                       |

Total: **11 split-candidates**. No exceptions yet — `commands.lua`'s decision is deferred to Phase 002 T006 once the file is read.

### Just-under-cap (review-only, no split planned)

- `lua/shooter/help.lua` — 314 LOC
- `lua/shooter/analytics/data.lua` — 313 LOC
- `lua/shooter/core/shotfile_fix.lua` — 312 LOC

These are within the cap but close. If a per-area phase finds a clean seam, splitting is welcome but not required.

## ALLOWED_LARGE_FILES

> Each entry is a file justified for exception from the 350-LOC soft cap. Format: `- <path>: <rationale>`. Empty until Phase 000 T005 / per-area phases populate it.
