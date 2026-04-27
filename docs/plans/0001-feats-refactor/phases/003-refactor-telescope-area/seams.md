# Seam plan — `telescope/` area split candidates

Produced by Phase 003 T001. Function inventories + per-file split decisions.

## Coverage baseline (from Phase 000 T003)

| file                                            | LOC | coverage |
|-------------------------------------------------|-----|----------|
| `lua/shooter/telescope/pickers.lua`             | 620 | n/a (UI-glue, runtime-only paths) |
| `lua/shooter/telescope/helpers.lua`             | 529 |  0.71%   |
| `lua/shooter/telescope/toggle_panes_picker.lua` | 232 |  1.74%   |

Coverage gates for Phase 003 T002+T003: each module ≥ 80% before refactor begins (or documented exception per spec § Open Questions).

## `telescope/helpers.lua` — DECISION: split

Functions cluster cleanly by **what data they fetch / mutate** rather than by domain. The plan-level architecture (sorter/filter/format/icon) does not match: those concerns already live in `shooter.session.{sort,filter}` and `shooter.telescope.recency`. Split per actual seams.

### Sub-modules (5 + init, all ≤ 215 LOC)

```
lua/shooter/telescope/helpers/
  init.lua           #  ~50 LOC — re-exports the public surface; owns
                                  M.persistent_state singleton (state-mod
                                  reads/writes via init.persistent_state)
  io.lua             #  ~50 LOC — get_file_mtime, read_lines, get_target_file
  shots.lua          #  ~85 LOC — find_open_shots, make_shot_entry,
                                  get_repo_prompt_files, get_all_repo_shots
  state.lua          #  ~85 LOC — clear_selection, save_selection_state,
                                  restore_selection_state
  files.lua          # ~215 LOC — get_prompt_files, get_all_repos_prompt_files
                                  (single-repo and all-repos prompt walkers)
  bullets.lua        #  ~70 LOC — get_bullet_files
```

`persistent_state` is module-level mutable state shared by `state.lua` (writers) and any code that reads it for display. Owning it in `init.lua` keeps a single source of truth; `state.lua` writes via `local init = require('shooter.telescope.helpers'); init.persistent_state[k] = v` (or via dedicated setters to avoid the require-cycle — chosen at T004 implementation time).

## `telescope/pickers.lua` — DECISION: split

Functions cluster by **picker kind** (file / shot / bullet) plus shared scaffolding (title, keymaps). The plan-level architecture (shotfile/plan/link/project/cli) doesn't match the actual file: it has only three picker kinds; `link_picker.lua` and `toggle_panes_picker.lua` are already separate files and out of scope. No `plan` or `project` picker exists in `pickers.lua` (project filtering is folded into the shotfile file picker via session config; plan files are surfaced via `add_plan_files` inside `helpers.get_prompt_files`).

### Sub-modules (5 + init, all ≤ 260 LOC)

```
lua/shooter/telescope/pickers/
  init.lua           #  ~25 LOC — re-exports (M.list_all_files,
                                  M.list_all_repos_files, M.list_open_shots,
                                  M.list_bullets_*, M.clear_selection,
                                  M.shot_picker_mode passthrough)
  title.lua          #  ~20 LOC — build_picker_title
  keymaps.lua        #  ~70 LOC — setup_folder_mappings,
                                  setup_session_mappings
  file.lua           # ~260 LOC — create_file_picker (the big one),
                                  list_all_files, list_all_repos_files
  shot.lua           # ~175 LOC — shot_picker_mode (table singleton),
                                  build_shot_entries, list_open_shots
  bullet.lua         #  ~90 LOC — get_repo_slug, create_bullet_picker,
                                  list_bullets_current_file,
                                  list_bullets_current_repo,
                                  list_bullets_all_repos
```

`shot_picker_mode` is module-level state (`'current' | 'all'`). Owning it in `shot.lua` (the only writer/reader) is cleanest; `init.lua` exposes it via `M.shot_picker_mode = require('shooter.telescope.pickers.shot').shot_picker_mode` getter or by re-binding through a getter/setter pair — chosen at T005 implementation time. Keep it on `M` of `init.lua` for backwards-compat with any external test/inspection.

## Public surface (cross-file)

`telescope/helpers.lua` (pre-split) exports 16 functions on M:
`get_file_mtime, persistent_state, clear_selection, get_target_file, read_lines, find_open_shots, make_shot_entry, get_repo_prompt_files, get_all_repo_shots, save_selection_state, restore_selection_state, get_prompt_files, get_all_repos_prompt_files, get_bullet_files`.

All 14 functions + the `persistent_state` table must remain reachable from `require('shooter.telescope.helpers')` post-split. Tests pin via existing `tests/telescope/helpers_spec.lua` plus T002's expansion.

`telescope/pickers.lua` (pre-split) exports 6 entry points on M:
`clear_selection, list_all_files, list_all_repos_files, shot_picker_mode, list_open_shots, list_bullets_current_file, list_bullets_current_repo, list_bullets_all_repos`. All preserved post-split via `init.lua` re-exports.

## Dep graph (no cycles expected)

```
helpers/{io} ← helpers/{shots, state, files, bullets} ← helpers/init
pickers/{title, keymaps, file, shot, bullet} ← pickers/init
pickers/* depends on helpers/* (entry-makers, shot detection)
```

`helpers/files.lua` is the heaviest — depends on `shooter.core.{files, project}`, `shooter.config`, `shooter.tools.git_worktree`, `shooter.utils`. `helpers/bullets.lua` depends on `shooter.core.ext_config`. Sub-modules do not require each other except through `init.lua` for persistent_state access.

## Path-traversal audit (input → T006)

`pickers.lua`'s new-shotfile-from-prompt flow (lines 281–324) routes user
prompt input through `slugify_path`/`generate_filename`. Both are
robust against `..` and absolute paths today (verified at
`lua/shooter/core/files/path.lua:50-76` — `[^%w%-]` strip eliminates `.`, leading `/` is consumed by `gmatch '[^/]+'`).

T006 scope:
- Add `tests/telescope/security_spec.lua` covering:
  - Prompt input `../etc/passwd` → file lands inside `docs/shotfiles/`, not parent dir.
  - Prompt input `/etc/passwd` → same.
  - Prompt input `./../foo` → same.
- Audit `entry.value.path` callers: lines 285 (`open_shotfile`), 309 (new file create), 573 (bullet edit), 462 (shot pane edit). All paths originate from trusted globs (`docs/shotfiles/**`, `bullets_root/**`). No fix required, but a defensive `assert_under(root, candidate)` at the picker boundary is cheap insurance — add inside helpers/io.lua as `M.assert_path_under(root, p)` (returns true/false; callers decide).
- Replace `helpers.lua:415, 438, 510` (`io.popen('ls -1 …')`) with `vim.fn.readdir` (per baseline.md security inventory). Already in T006 scope.

## Risks

- Telescope's API can change between versions; tests stub the small surface used (`pickers.new`, `finders.new_table`, `actions.select_default`) — not the whole library.
- Pickers depend on user theme/colorscheme; entry display is mostly visual — coverage of display functions can be high but the visual outcome isn't asserted. Acceptable per spec.
- `helpers.lua` is at **0.71%** baseline coverage. T002 must lift to ≥ 80% — concrete addition: cover `find_open_shots, make_shot_entry, read_lines, get_repo_prompt_files, get_all_repo_shots, get_prompt_files, get_all_repos_prompt_files, get_bullet_files, save_selection_state, restore_selection_state, clear_selection, get_file_mtime`. Picker callbacks and live-Neovim handlers stay headlessly unreachable.
- `pickers.lua` is UI-glue; T003 must either reach 80% via stubbing telescope or document the exception in `baseline.md` with explicit rationale (per spec Open Q #1).

## Tasks-first plan summary

T002 lifts `helpers.lua` from 0.71% → ≥ 80% via per-function specs (mostly pure functions with table inputs). Estimated ~12 new spec descriptions on top of existing.

T003 covers `pickers.lua` shape: stub telescope, assert picker config (titles, layouts, keymap registrations) without firing finders. Likely tops out at 60-70% headlessly; the gap moves to `baseline.md` ALLOWED_BELOW_THRESHOLD with rationale.

Splits then proceed in dep order: `helpers/` (T004), `pickers/` (T005). T006 ships security fixes + path-traversal tests. T007 verifies full state.
