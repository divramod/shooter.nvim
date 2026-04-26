# Seam plan — `core/` area split candidates

Produced by Phase 002 T001. Function inventories + per-file split decisions.

## Coverage baseline (from Phase 000 T003)

| file                                 | LOC  | coverage |
|--------------------------------------|------|----------|
| `lua/shooter/commands.lua`           | 1190 | n/a (not in baseline output — commands.lua is touched only at startup) |
| `lua/shooter/core/shot_actions.lua`  |  795 | 47.37%   |
| `lua/shooter/core/files.lua`         |  456 | 72.20%   |
| `lua/shooter/core/ext_config.lua`    |  416 | 79.81%   |
| `lua/shooter/core/shotfile_fix.lua`  |  312 | 57.95%   |

Coverage gates for Phase 002 T002+T003: each module ≥ 80% before refactor begins.

## `commands.lua` — DECISION: split

Already structured as a flat dispatcher: a single `M.setup()` calls 18 internal `setup_<area>_commands()` functions. Splitting along the existing seam is mechanical and improves grep-ability.

### Sub-modules (10 files, all ≤ 260 LOC)

```
lua/shooter/commands/
  init.lua         #  ~70 LOC — M.setup() calls every sub-area's setup() in order
  util.lua         #  ~25 LOC — require_shotfile, create_cmd helpers
  shotfile.lua     # ~160 LOC — setup_shotfile_commands (lines 24-182 of original)
  shot.lua         # ~140 LOC — setup_shot_commands (183-318)
  plan.lua         # ~130 LOC — setup_plan_commands (360-484)
  cfg.lua          # ~260 LOC — setup_cfg_commands + setup_hal_config_commands +
                                setup_hal_config_picker (533-625, 626-676, 1090-1149)
  tool.lua         #  ~50 LOC — setup_tool_commands (485-532)
  tmux.lua         #  ~45 LOC — setup_tmux_commands (319-359)
  utility.lua      # ~250 LOC — setup_utility + setup_nav + setup_bullet
                                (807-1037, 711-788, 1150-1170)
  misc.lua         # ~170 LOC — setup_analytics, setup_help, setup_git_worktree,
                                setup_domain, setup_session
                                (677-687, 688-710, 789-806, 1038-1060, 1061-1089)
```

Registration order matters. `init.lua`'s `M.setup()` calls each sub-area's `setup()` in the original order, preserving startup behavior.

A registration smoke test (added in T003) enumerates expected `:HalShooter*` user commands and asserts all are registered post-setup.

## `core/shot_actions.lua` — DECISION: split

Functions naturally cluster by action class.

### Sub-modules (7 + init, all ≤ 220 LOC)

```
lua/shooter/core/shot_actions/
  init.lua         #  ~50 LOC — re-exports public surface
  create.lua       # ~220 LOC — find_insertion_line, create_new_shot,
                                create_new_shot_with_whisper, create_shot_from_file,
                                create_shot_from_claude, write_shot_creator_script
  delete.lua       #  ~70 LOC — delete_last_shot
  navigate.lua     # ~130 LOC — goto_next_open_shot, goto_prev_open_shot,
                                goto_latest_sent_shot, get_sent_shots_sorted,
                                goto_prev_sent_shot, goto_next_sent_shot
  state.lua        # ~100 LOC — toggle_shot_done, undo_latest_sent_shot
  extract.lua      # ~170 LOC — yank_shot, extract_subtask, extract_line
  info.lua         #  ~20 LOC — file_stats
```

## `core/files.lua` — DECISION: split

### Sub-modules (5 + init, all ≤ 160 LOC)

```
lua/shooter/core/files/
  init.lua         #  ~60 LOC — re-exports
  predicate.lua    #  ~80 LOC — is_metaplan, is_plan_file, is_plan_idea,
                                is_last_trackable, is_in_prompts_folder,
                                is_shooter_file
  last_shotfile.lua #  ~85 LOC — _last_shotfile_path_for_main, _persist,
                                 _load, track_last_shotfile, find_last_file,
                                 get_last_edited_file
  git.lua          #  ~45 LOC — get_git_root, get_cwd_git_root, get_file_git_root
  path.lua         # ~150 LOC — get_current_file_path, get_current_file_or_folder_path,
                                get_prompts_dir, slugify_segment, slugify_path,
                                generate_filename, title_from_path, update_file_title
  io.lua           # ~115 LOC — open_shotfile, create_file, get_file_title,
                                get_prompt_files, ensure_theme_shotfiles
```

## `core/ext_config.lua` — DECISION: split

### Sub-modules (4 + init, all ≤ 110 LOC)

```
lua/shooter/core/ext_config/
  init.lua         #  ~50 LOC — re-exports + load entry
  paths.lua        #  ~50 LOC — base_dir, sessions_dir, bullets_dir, tmp_dir,
                                filter_state_path, last_shotfile_path,
                                global_config_path, local_config_path
  yaml.lua         #  ~95 LOC — parse_yaml, serialize_yaml
  load.lua         #  ~95 LOC — ensure_global_config, ensure_local_config,
                                fix_empty_table_leaves, load, get, reload
  fix.lua          # ~110 LOC — strip_to_schema, fill_from_schema, count_leaves,
                                fix_config
```

## `core/shotfile_fix.lua` — DECISION: review-only, no split

312 LOC is under the 350 cap. Functions are cohesive (single-file fix-up pipeline). Splitting would fragment a logical unit. Keep as-is.

If future work pushes it over 350, candidates would be:
- `shotfile_fix/parse.lua` — is_fence, find_shot_ranges, header_has_no_title
- `shotfile_fix/normalize.lua` — normalize_blank_lines, strip_trailing_blanks, strip_empty_shots
- `shotfile_fix/commit.lua` — build_commit_message, commit, fix_file, run_all, run

But for now, no split.

## Public surface (cross-file)

Every public function on `M` of the original files is re-exported by the new `init.lua` shims. The 30-fn pattern from Phase 001 applies. Test discipline: `tests/core/<file>_public_surface_spec.lua` (or fold into existing _specs) asserts each export exists post-split.

## Dep graph (no cycles expected)

```
ext_config/{paths, yaml} ← ext_config/load ← ext_config/fix ← ext_config/init
files/{git, predicate, path}        ← files/{last_shotfile, io} ← files/init
shot_actions/{create,delete,navigate,state,extract,info} ← shot_actions/init
commands/{util, shotfile, shot, plan, cfg, tool, tmux, utility, misc} ← commands/init
```

`commands/*` import from many places (utils, shooter.core.*, telescope, etc.) but not from each other (each is a self-contained registration block).

`shot_actions/*` mostly use shooter.core.files + shooter.core.shotfile_fix as deps; sub-modules can call each other via `require('shooter.core.shot_actions.<x>')` if needed (current code has small cross-references).

## Risks

- `commands.lua`'s `setup_<area>_commands` order matters. `init.lua`'s `M.setup()` must call every sub-area's setup() in the original order. T006's registration smoke test catches drift.
- `files.lua` has many cross-uses inside the file (e.g. `slugify_path` calls `slugify_segment`). The split keeps related pure helpers in `path.lua`.
- `ext_config.lua` has a hot path: `M.get(dot_path)` is called from many user-command handlers. The split must not introduce extra `require` cost on hot calls.

## Tasks-first plan summary

T002 closes coverage gaps for `files.lua` (72.20→80%) and `ext_config.lua` (79.81→80%) — small additions.

T003 closes the bigger gaps: `shot_actions.lua` (47→80%, +33pp) and `shotfile_fix.lua` (58→80%, +22pp). Plus a thin contract spec for `commands.lua` (registration enumeration).

Splits then proceed in dep order: `ext_config` (T005, smallest), `files` (T004), `shot_actions` (T007), `commands` (T006).

T008 applies security fixes catalogued for core/ in `baseline.md`:
- `core/project.lua:45` — `io.popen('ls -1 "' .. projects_dir`)
- `core/repos.lua:39` — `io.popen('ls -d "' .. expanded_dir`)
- `core/shot_actions.lua:768-789` — tmux pane interpolation
- `core/files.lua:104,111,120,133` — already mostly table-form or shellescape-d
- `utils.lua:128,139,204` — generic helpers (utils.lua is root, not core/)
