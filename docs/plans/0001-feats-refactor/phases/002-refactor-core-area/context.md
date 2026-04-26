---
name: refactor-core-area-context
description: Phase 002 context — files, patterns, gotchas for the core/ + commands.lua refactor.
---

# Context — Phase 002

## Files to Load

- `lua/shooter/commands.lua` (1190 LOC) — split candidate
- `lua/shooter/core/shot_actions.lua` (795 LOC)
- `lua/shooter/core/files.lua` (456 LOC)
- `lua/shooter/core/ext_config.lua` (416 LOC)
- `lua/shooter/core/shotfile_fix.lua` (312 LOC) — review-only
- `lua/shooter/utils.lua` — shell-out helpers, touched by T008
- `lua/shooter/init.lua` — plugin entrypoint; verify command-registration call path
- `tests/core/` and `tests/commands*` — existing tests, avoid duplication

## Patterns

- **User-command registration smoke test:** `vim.api.nvim_get_commands({})` enumerates user commands; the test asserts every expected `:HalShooter…` is present after `require('shooter').setup()`.
- **Shellescape policy:** for any shell string interpolation, `vim.fn.shellescape(path)` on the path. Better: `vim.fn.system({"git", "-C", path, ...})` table form — no shell, no escaping needed.
- **Git command pattern:** `vim.fn.systemlist({"git", "-C", root, "rev-parse", "--show-toplevel"})` — table form; `vim.v.shell_error` for status. Avoids the historical `'git -C ' .. shellescape(dir) .. ' …'` string-form.
- **tmux send-keys safety:** pane id from `tmux display-message -p '#{pane_id}'` returns `%N`. Validate the regex `^%[0-9]+$` before interpolating.

## Gotchas

- `commands.lua` is 1190 LOC of mostly `vim.api.nvim_create_user_command(...)` calls. Splitting may be mechanical (one command per line) but registration order can matter if commands depend on prior `setup()` state.
- `shot_actions.lua:768-779` shows a known-issue tmux pane interpolation; treat as a high-risk security site.
- `core/project.lua:45` interpolates `projects_dir` into a quoted string with no shellescape — `"; rm -rf .` in the path would inject. High-risk.
- `core/files.lua` shells out to `git` four times in 30 lines (lines 104, 111, 120, 133); refactor to a single helper `core/files/git.lua` while preserving behavior.

## Links

- Spec: `../../../spec.md`
- Masterplan: `../../../masterplan.md`
- Phase plan: `./plan.md`
