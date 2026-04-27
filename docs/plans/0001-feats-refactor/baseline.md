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

### Gaps escalated to Phase 005 T002

Per-file 80% gates that are structurally hard to lift in their owning phase (functions need real buffer / filesystem / tmux state that's expensive to fixture per-test). These get pushed in Phase 005 T002 alongside the global 80% closure:

- **`lua/shooter/commands.lua`** — currently 35.45% post-T003. The `commands_registration_spec.lua` exercises `M.setup()` which loads every `setup_<area>_commands` block, but most individual command callbacks are never invoked. Phase 005 will either invoke each `:HalShooter*` command in a stubbed env or document the gap as `ALLOWED_BELOW_THRESHOLD` with rationale.
- **`lua/shooter/core/shot_actions.lua`** — currently 47.37%. Many functions (yank/extract/navigate/create-from-claude) need realistic shotfile buffer state. Phase 005 invests in fixture infrastructure or accepts an exception.
- **`lua/shooter/core/shotfile_fix.lua`** — currently 62.05%. Per the seam plan it's review-only (no split). Coverage push is straightforward in Phase 005 once a shotfile fixture helper exists.

## Security Inventory

**Source:** Audit greps run in Phase 000 T004 (raw output: `/tmp/secaudit.log` regen with the commands in spec.md § Commands).

**Headline findings:**

- **~95 shell-out sites** total. Roughly **35 high-risk** (string-interpolation with caller-controlled paths or commands), **40 medium-risk** (string-form with bounded inputs), **20 low-risk / safe** (table-form `vim.fn.system({...})` or fixed string).
- **Dynamic code execution: clean.** No `loadstring`, `load(<userdata>)`, `dofile`, or `loadfile` calls. `M.load(...)` matches in the grep are function definitions, not exec sites. Success Criterion #4 is trivially satisfied today and just needs to stay that way.
- **Temp-file handling: 2 TOCTOU-prone sites** (`tmux/keys.lua:15`, `tmux/send.lua:62` — both use `os.tmpname()` which creates a predictable name and is race-vulnerable). Plus **2 predictable-path sites** in shell scripts under `tmux/toggle_panes.lua:351,356` (`/tmp/shooter-pane-$PANE_ID`, `/tmp/shooter-folder-$PANE_ID` — safe iff `$PANE_ID` is validated server-side, which needs verification).
- **File permissions: not used.** No `chmod`, `vim.fn.setfperm`, or `setfperm`. Files inherit process umask. The plugin doesn't write secret-bearing files, so this is acceptable; just noting that any future secret-write must explicitly set restrictive perms.

### High-risk shell-out sites (Phase 1+ must fix)

Each row: file:line — pattern — phase — concrete fix.

| file:line                                          | pattern                                      | phase | fix |
|----------------------------------------------------|----------------------------------------------|-------|-----|
| `core/project.lua:45`                              | `io.popen('ls -1 "' .. projects_dir .. '"')` | 002   | replace with `vim.fn.readdir` (no shell) |
| `core/repos.lua:39`                                | `io.popen('ls -d "' .. expanded_dir .. '"/*/ ')` | 002 | `vim.fn.readdir` + filter |
| `core/shot_actions.lua:779`                        | `'tmux send-keys -t ' .. right_pane`         | 002   | validate `right_pane` matches `^%[a-zA-Z0-9_]+$` |
| `core/shot_actions.lua:789`                        | `'tmux select-pane -t ' .. right_pane`       | 002   | same validation |
| `health.lua:226`                                   | `string.format('find "%s" …', full_path)`    | 004   | `vim.fn.system({'find', full_path, ...})` table-form |
| `inbox/init.lua:33`                                | `'find "' .. expanded_dir .. '"…'`           | (root)| same — table-form |
| `utils.lua:128`                                    | `io.popen(cmd)` — `cmd` from caller          | 002   | rename helper, document caller-must-shellescape contract |
| `utils.lua:204`                                    | `'grep -l "shooter" "' .. plugins_dir .. '"…'`| 002  | table-form |
| `dashboard/data.lua:123,191`                       | `'ls -1 "' .. projects_dir`                  | (root)| `vim.fn.readdir` |
| `telescope/helpers.lua:415,438,510`                | `'ls -1 "' .. *_dir .. '"'`                  | 003   | `vim.fn.readdir` |
| `analytics/data.lua:155,186,206`                   | `'ls -d "' .. expanded_dir / 'find "…"'`     | 004   | `vim.fn.readdir` / `vim.fs.find` |
| `tmux/script_panes.lua:22,53,65`                   | `string.format("test -x '%s'", path)` etc.   | 004   | `vim.loop.fs_stat` for the test-x; table-form for ls |
| `tmux/shell.lua:8,46`                              | `string.format("…", …)` shell-outs           | 004   | table-form |
| `tmux/panes.lua:21,33,129`                         | `string.format("tmux …", …)`                 | 004   | table-form `{'tmux', ...}` |
| `tmux/detect.lua:139`                              | `string.format("tmux list-panes …grep -x '%s'", pane_id)` | 004 | validate pane_id; replace with substring match in Lua |
| `tmux/wrapper.lua:8,19`                            | `'tmux ' .. cmd` / `script_path .. ' …'`     | 004   | table-form; for `script_path`, `vim.fn.shellescape` |
| `tmux/send.lua:56`                                 | `cmd .. " 2>/dev/null"` — caller-controlled  | 004   | document contract or refactor caller |
| `tmux/hidden_session.lua:12`                       | `cmd .. ' 2>/dev/null'`                      | 004   | same |
| `tmux/watch.lua:19`                                | `'tmux ' .. cmd .. ' 2>/dev/null'`           | 004   | table-form |
| `tmux/toggle_panes.lua:23`                         | `cmd .. ' 2>/dev/null'`                      | 004   | document caller contract |
| `images.lua:40`                                    | `'tmux split-window…' .. tmpfile .. ' ; …'.. wait_channel .. '"'` | (root) | the `;` here is *especially* dangerous — table-form + table-of-args |
| `images.lua:41`                                    | `'tmux wait-for ' .. wait_channel`           | (root)| validate wait_channel |
| `commands.lua:722,1080,1095`                       | `io.popen(cmd)` / `string.format(...)`       | 002   | table-form / readdir |
| `providers/init.lua:50,66,90,116,139`              | `io.popen(string.format(…, pane_id / pattern))` | (root)| validate pane_id; pattern is a known set |
| `providers/codex.lua:31`                           | `{"sh", "-c", cmd .. " 2>/dev/null"}`        | (root)| `cmd` is shell-interpreted; refactor to direct exec |
| `providers/copilot.lua:26`, `providers/opencode.lua:28`, `providers/gemini.lua:31` | same pattern as codex | (root)| same |
| `telescope/toggle_panes_picker.lua:22`             | `io.popen(string.format(…))`                 | 003   | table-form |

### Medium-risk shell-out sites

These are string-form but with bounded / no-user-input. Audit during the relevant phase; replace with table-form when convenient. Examples: `core/files.lua:104,111,120` (no interpolation), `syntax.lua:296`, `core/ext_config.lua:90`, `telescope/pickers.lua:533`, `health.lua:87,111` (fixed strings), `tmux/operations.lua:13,40`, `tmux/watch.lua:8,39,69`, `health/tools.lua:15,40,59`, `tools/clipboard_image.lua:26,34,44` (script-rel + shellescape), `tools/git_worktree.lua:18,50,170,172` (uses `shellescape`).

### Low-risk / safe (already table-form)

`tmux/create.lua:43,48,71,74`, `core/shotfile_fix.lua:203,208,214,262,264,278`, `plans/metaplan.lua:278,797`, `tools/links.lua:94`, `tmux/operations.lua:13`, `core/shot_actions.lua:768` (table-form). Keep as the template for migrations.

### Tempfile findings

| file:line                            | issue                                               | fix |
|--------------------------------------|-----------------------------------------------------|-----|
| `tmux/keys.lua:15`                   | `os.tmpname()` — race + predictable                 | `vim.fn.tempname()` (Neovim's, more secure) |
| `tmux/send.lua:62`                   | same                                                | same |
| `tmux/toggle_panes.lua:351,356`      | predictable `/tmp/shooter-pane-$PANE_ID` (shell)    | use `mktemp` + ensure `$PANE_ID` is validated upstream |

### Unhandled categories (clean)

- **Dynamic exec:** no findings ✓
- **File-perm setters:** no findings ✓ (acceptable — no secret-write)
- **Path-traversal in user-controlled rename:** see `plans/metaplan.lua` (rename ops); in scope for Phase 001 T005 testing.

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

## ALLOWED_BELOW_THRESHOLD

> Per-file 80% coverage exceptions logged by per-area phases. Format: `- <path>: <coverage> — <rationale>`.

- `lua/shooter/telescope/pickers/file.lua`: **55.75%** post-T005 — UI-glue. The `pickers_spec.lua` stubs telescope and asserts picker construction (title, layout, finder shape) for all entry points. The uncovered 44% is `attach_mappings` handler bodies (per-key callbacks: move-to-folder, rename, delete, session save/load, layout toggle, the `select_default:replace(...)` create-from-prompt fallback). Bodies only execute against a live telescope picker; headless invocation either short-circuits at `actions.close(prompt_bufnr)` or recurses back into `M.list_all_files(...)` and deadlocks. Per spec § Open Q #1 ("UI-glue requires interactive Neovim"). Phase 005 T002 may revisit.
- `lua/shooter/telescope/pickers/shot.lua`: **60.50%** post-T005 — same rationale: `attach_mappings` handler bodies for shot send / toggle done / mode toggle.
- `lua/shooter/telescope/pickers/keymaps.lua`: **56.10%** post-T005 — folder/session mapping callback bodies; same rationale.
- `lua/shooter/tools/git_worktree/picker.lua`: **21.05%** post-phase-004-T007 — UI-glue. The Telescope picker construction code (`pickers.new(... entry_maker = function(entry) ... end, attach_mappings = function(prompt_bufnr, map) ... end ... ):find()`) executes only against a live Telescope instance with focused prompt buffer. Headless tests can stub the picker module to verify call structure, but the callback bodies (entry_maker, attach_mappings, select_default replacement) only fire under a real picker. Same rationale as `telescope/pickers/file.lua`. Phase 005 T002 may revisit.
- `lua/shooter/syntax/autocmds.lua`: **58.44%** post-phase-004-T005 — autocmd callbacks. The `setup()` function registers autocmds (BufEnter, TextChanged, FileChangedShell, vim.fn.timer_start, BufWritePost on config.yaml, BufEnter on config.yaml, BufDelete) whose bodies execute only when the corresponding event fires against a buffer matching the configured patterns. Headless tests trigger the BufEnter+TextChanged+ColorScheme branches via `nvim_exec_autocmds`, but the config.yaml fix-on-save / fix-on-enter / timer-checktime / FileChangedShell branches are gated on filesystem state + 1-second timer + nvim event-loop interaction that's expensive to fixture. Phase 005 may revisit.
- `lua/shooter/analytics/data/sources.lua`: **60.56%** post-phase-004-T007 — repo discovery walks `repos.direct_paths` + `repos.search_dirs` from user config; tests can't easily inject populated config without leaking into the user's home repos. The `get_all_repo_paths` happy-path is exercised; the `get_all_shots` projects/* subdir branch needs a fixture repo with both `docs/shotfiles/*.md` and `projects/*/docs/shotfiles/*.md` to hit fully. Acceptable.

## Phase 004 T008 — deferred shell-out hardening

The following Phase 004-area shell-out sites from the high-risk table above
are **deferred to a follow-up plan**. T008 explicitly hardened the four
deliverables called out in `phases/004-refactor-tmux-tools-misc/plan.md`
(`health.lua` lines 87/111/226 → table-form; `tools/git_worktree.lua` →
table-form; `analytics/data.lua` → `vim.fn.readdir` + `vim.fs.find`;
`syntax.lua:296` → table-form via `syntax/info.lua`). The remaining
`tmux/*` wrappers are tracked here so phase 005 (or a dedicated plan)
can sweep them:

- `tmux/wrapper.lua:8,19` — `io.popen('tmux ' .. cmd .. ' 2>/dev/null')` wrapper.
  All current internal callers pass static literal commands; risk is theoretical
  (the wrapper is permissive but no caller-controlled value reaches it today).
- `tmux/send.lua:56,153,176-179` — `vim.fn.system(cmd .. ' 2>/dev/null')` where
  `cmd` chains together tmux send-keys/load-buffer/paste-buffer with interpolated
  `pane_id`, `tmpfile`, and `filepath`. **`filepath` in `send_file_reference`
  IS caller-controlled.** Hardening requires refactoring the chained-shell
  pattern into a sequence of table-form `vim.fn.system({...})` calls (medium
  effort; behavior-preserving).
- `tmux/hidden_session.lua:12` — same wrapper pattern as `wrapper.lua`. Internal
  callers all use `HIDDEN_SESSION` constant or `pane_id` from tmux output.
- `tmux/watch.lua:19` — same wrapper pattern.
- `tmux/toggle_panes/exec.lua:5,16` — same wrapper pattern (post-T007).
- `tmux/script_panes.lua:22,53,65` — `string.format("test -x '%s'", path)` etc.
- `tmux/panes.lua:21,33,129` — `string.format("tmux …", …)`.
- `tmux/detect.lua:139` — `string.format("tmux list-panes …grep -x '%s'", pane_id)`;
  `pane_id` should be validated to `^%%?[%w_]+$` before this call.
- `tmux/shell.lua:8,46` — `string.format("…", …)` shell-outs.

Spec gap-classifier rating: **small** (per-file, no public API change). Tracked
under Phase 005 cleanup or a dedicated `0002-tmux-shell-out-hardening` plan.
