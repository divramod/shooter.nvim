# Phase 004 — Per-File Seam Plan

Produced by T001. Each split-target lists current LOC, observed responsibilities, and the proposed sub-module layout. Sub-modules target ≤ 350 LOC each; each split keeps the original file as a re-export shim for backward compatibility (matches phase 002/003 pattern).

## syntax.lua (513 LOC)

**Observed responsibilities** (read of `lua/shooter/syntax.lua`):

- L7–79  `define_highlights()` — pure highlight-group definitions from config.
- L82–103 `is_fence_delimiter` + `build_code_block_map` — fenced-code-block detection helpers.
- L118–138 `split_executed_header` — parser for `## x shot N <title> (ts) @ref` header.
- L144–247 `apply_syntax` — extmark engine: walks lines, builds matches, clears + sets extmarks. The single hot path. Calls `markdown_links` for non-shot lines.
- L250–255 `is_prompts_file` — path predicate.
- L258–267 `M.toggle_day_marker` — public toggle that flips local state + reapplies.
- L269–302 `show_shotfile_info` + `notified_bufs` — one-shot per-buffer notification.
- L305–455 `M.setup` — autocommand wiring (BufEnter, TextChanged, FileChangedShell, timer, BufDelete, ColorScheme, BufWritePost/BufEnter for `config.yaml`).
- L459–511 `M.reapply_all` + `apply_override` — config-override fold + reapply.

**Plan.md proposed seam:** per syntax group (`shot_headers / bullets / links / meta`). **Rejected** as not faithful to the code — `apply_syntax` is one engine that handles every match type in a single O(n) pass. Splitting per-group would require a structural rewrite (iterate-once → iterate-N-matchers) outside the scope of this phase.

**Adopted seam plan:** layer-based.

```
lua/shooter/syntax/
  init.lua           # ≤ 50  — re-export setup/reapply_all/toggle_day_marker
  highlights.lua     # ≤ 80  — define_highlights()
  detect.lua         # ≤ 70  — is_fence_delimiter, build_code_block_map,
                     #         split_executed_header, is_prompts_file
  apply.lua          # ≤ 130 — apply_syntax + ns + day_marker_enabled,
                     #         M.toggle_day_marker (touches state)
  info.lua           # ≤ 60  — show_shotfile_info + notified_bufs
  autocmds.lua       # ≤ 170 — M.setup (autocommand wiring only)
  overrides.lua      # ≤ 80  — apply_override + reapply_all
lua/shooter/syntax.lua # shim — `return require('shooter.syntax')`
```

`apply.lua` keeps `day_marker_enabled` and the `ns` namespace as module-locals so `toggle_day_marker` and `apply_syntax` share state without an extra module. `notified_bufs` lives in `info.lua` for the same reason.

---

## health.lua (369 LOC)

**Observed responsibilities:**

- L7–64    Plugin checks: telescope, oil.nvim, vim-tmux-navigator, gp.nvim.
- L67–76   Env: iTerm detection.
- L79–130  tmux: installed?, in tmux?, claude process detection.
- L133–196 Context files: global, project.
- L199–296 Shotfile-area: prompts directory (with `find` shell-out), queue file (JSON validation).
- L299–367 `M.check` orchestrator (`vim.health.start` sections + dispatch).

**Adopted seam plan:**

```
lua/shooter/health/
  init.lua           # ≤ 80   — M.check entry; orchestrator only
  plugins.lua        # ≤ 80   — telescope/oil/tmux_navigator/gp checks
  system.lua         # ≤ 80   — iterm + tmux_installed + in_tmux + claude_process
  context.lua        # ≤ 80   — global_context + project_context
  shotfile.lua       # ≤ 90   — prompts_directory (find shell-out fix here) + queue_file
lua/shooter/health.lua # shim — `return require('shooter.health')`
```

Note: `lua/shooter/health/tools.lua` (`check_hal_cli`, `check_python`, `check_ttok`) already exists and is used; keep as-is (no split needed).

---

## tmux/toggle_panes.lua (377 LOC)

**Observed responsibilities:**

- L17     module-local `state` table — keyed by pane name.
- L19–35  `tmux_exec`, `tmux_run` — shell wrappers (KNOWN: `io.popen(cmd .. ' 2>/dev/null')` — fix in T008).
- L41–90  layout helpers: `get_pane_height_percent`, `pane_exists`, `create_bottom_pane`, `get_hidden_window_name`.
- L95–129 marker helpers: `get_pane_name_file`, `get_folder_file`, `setup_pane_for_hiding` (writes `/tmp/shooter-pane-<id>` and `/tmp/shooter-folder-<id>`).
- L134–142 `run_commands` — sends key sequences to a pane.
- L147–322 public actions: `M.hide`, `M.show`, `M.toggle`, `M.is_visible`, `M.is_hidden`, `M.get_visible_panes`, `M.get_state`, `M.clear_state`.
- L331–375 `M.setup_tmux_keybinding` — installs root-table M-A binding (large heredoc shell snippet).

**Adopted seam plan:**

```
lua/shooter/tmux/toggle_panes/
  init.lua           # ≤ 60   — module-local `state` + re-exports
  exec.lua           # ≤ 30   — tmux_exec, tmux_run
  layout.lua         # ≤ 60   — height/exists/create/window_name
  marker.lua         # ≤ 50   — pane/folder temp-file marker helpers
  actions.lua        # ≤ 180  — hide/show/toggle/is_visible/is_hidden/getters/clear_state
                     #         + run_commands
  keybinding.lua     # ≤ 60   — setup_tmux_keybinding
lua/shooter/tmux/toggle_panes.lua # shim
```

`state` lives on `init.lua` and is passed to `actions.lua` as a constructor arg (or accessed via `local state = require('...init').state`). The latter keeps function signatures clean.

---

## tools/git_worktree.lua (378 LOC)

**Observed responsibilities** (read-only — no create/delete; the file is list-and-switch despite the plan.md outline mentioning `create.lua / delete.lua`):

- L9–40    `get_repo_name`, `git_cmd` — git introspection (cwd → buffer dir fallback).
- L43–93   listing: `get_worktrees`, `get_main_worktree`, `get_numbered_worktrees`.
- L121–130 `get_relative_file` — current file → repo-relative path.
- L133–218 LAST-file state: `get_repo_wt_state_dir`, `ensure_gitignore`, `save_last_worktree`, `read_last_worktree`.
- L221–256 `switch_to_worktree` — buffer-close + cd + edit-target.
- L259–340 picker entry points: `M.switch_to`, `M.pick_worktree` (Telescope), `M.to_last`, `M.to_main`.

**Plan.md proposed seam:** `init / list / create / delete`. **Rejected** — there is no create/delete code in this file. Rename to layer-based per actual responsibilities.

**Adopted seam plan:**

```
lua/shooter/tools/git_worktree/
  init.lua           # ≤ 60   — re-export public M.* + M.get_main_worktree
  repo.lua           # ≤ 60   — get_repo_name, git_cmd, get_relative_file
  list.lua           # ≤ 60   — get_worktrees, get_main_worktree, get_numbered_worktrees
  state.lua          # ≤ 90   — get_repo_wt_state_dir, ensure_gitignore,
                     #         save_last_worktree, read_last_worktree
  switch.lua         # ≤ 80   — switch_to_worktree, M.switch_to, M.to_last, M.to_main
  picker.lua         # ≤ 80   — M.pick_worktree (Telescope finder)
lua/shooter/tools/git_worktree.lua # shim
```

---

## analytics/data.lua (313 LOC, *under cap*)

**Just under the 350 cap.** Per baseline.md "Just-under-cap (review-only, no split planned)". Plan T007 still mentions it as a split target — split is **welcome but not required**. The seams below are the recommended split if T007 chooses to act; otherwise document the just-under-cap status.

**Observed responsibilities:**

- L9–80    parse: `parse_executed_shot_header`, `get_shot_metrics`, `parse_shotfile`.
- L83–122  repo: `get_git_remote_info`, `detect_project_from_path`, `repo_matches_filter`.
- L125–227 sources: `get_all_repo_paths`, `get_all_shots` (KNOWN: `io.popen(... find / ls ...)` interpolation — fix in T008).
- L230–311 stats: `get_time_boundaries`, `calculate_stats`, `build_path_map`.

**Adopted seam plan (recommended for T007; optional):**

```
lua/shooter/analytics/data/
  init.lua           # ≤ 40   — re-export
  parse.lua          # ≤ 90   — parse_executed_shot_header/get_shot_metrics/parse_shotfile
  repo.lua           # ≤ 50   — git_remote_info/detect_project/repo_matches_filter
  sources.lua        # ≤ 110  — get_all_repo_paths + get_all_shots (security fixes here)
  stats.lua          # ≤ 80   — time_boundaries/calculate_stats/build_path_map
lua/shooter/analytics/data.lua # shim
```

---

## Just-under-cap files (per Open Questions, review-only — no split)

Confirmed during T001 read.

- **`lua/shooter/help.lua`** — **314 LOC**. Static help-text dispatcher. No clean seam (top-level table of help blocks); splitting would only fragment grep-ability. **Decision: no split.** Add to `ALLOWED_LARGE_FILES:` only if it ever crosses 350; it currently doesn't.
- **`lua/shooter/core/shotfile_fix.lua`** — **312 LOC**. Already touched in Phase 002 (review-only there). **Decision: no split.** Same rationale as help.lua.

---

## T008 security fix targets surfaced during read

Cross-references `baseline.md` § High-risk shell-out sites for Phase 004:

- `lua/shooter/health.lua:87` — `io.popen('tmux -V 2>/dev/null')` (fixed string — low risk; convert to table-form for consistency).
- `lua/shooter/health.lua:111` — `io.popen("ps aux | grep '[c]laude' 2>/dev/null")` (fixed shell pipeline — refactor to `vim.fn.system({'pgrep', ...})`).
- `lua/shooter/health.lua:226` — `io.popen(string.format('find "%s" -name "*.md" -type f 2>/dev/null | wc -l', full_path))` — interpolated path, table-form.
- `lua/shooter/syntax.lua:296` — `vim.fn.systemlist('git rev-parse --show-toplevel 2>/dev/null')` (fixed string — table-form for consistency).
- `lua/shooter/tools/git_worktree.lua:12,18,44,50,170,172` — many `vim.fn.systemlist` / `vim.fn.system` with `git -C <shellescape>` — already use shellescape; convert to table-form for defence-in-depth.
- `lua/shooter/tmux/toggle_panes.lua:23,35` — `cmd .. ' 2>/dev/null'` — `cmd` comes from local callers (string.format with `%s` substituted); fix at the boundary by switching to table-form `vim.fn.system({...})`.
- `lua/shooter/analytics/data.lua:86,131,155,186,206` — `io.popen` / `utils.system` with interpolated paths; table-form + `vim.fn.readdir` / `vim.fs.find`.
- `lua/shooter/tools/tmux_panes.lua:6` — already noted in plan; review caller-side sanitization.

T008 will land all of these and add `tests/security/area_004_spec.lua` with grep assertions that no string-form `io.popen`/`vim.fn.system*` interpolation remains in the touched files.

---

## Summary

| target file                          | LOC | sub-modules | shim |
|--------------------------------------|-----|-------------|------|
| `lua/shooter/syntax.lua`             | 513 | 6           | yes  |
| `lua/shooter/health.lua`             | 369 | 5           | yes  |
| `lua/shooter/tmux/toggle_panes.lua`  | 377 | 6           | yes  |
| `lua/shooter/tools/git_worktree.lua` | 378 | 6           | yes  |
| `lua/shooter/analytics/data.lua`     | 313 | 5           | yes  |
| `lua/shooter/help.lua`               | 314 | — (no split)| —    |
| `lua/shooter/core/shotfile_fix.lua`  | 312 | — (no split)| —    |
