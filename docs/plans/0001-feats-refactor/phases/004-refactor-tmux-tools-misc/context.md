---
name: refactor-tmux-tools-misc-context
description: Phase 004 context — files, patterns, gotchas for the catch-all refactor.
---

# Context — Phase 004

## Files to Load

- `lua/shooter/syntax.lua` (513)
- `lua/shooter/tmux/toggle_panes.lua` (377)
- `lua/shooter/tools/git_worktree.lua` (378)
- `lua/shooter/health.lua` (369)
- `lua/shooter/help.lua` (314) — review only
- `lua/shooter/analytics/data.lua` (313)
- `lua/shooter/core/shotfile_fix.lua` (312) — review only

## Patterns

- **Health check pattern:** each top-level `M.check_<name>` function calls `vim.health.start(...)` then `vim.health.ok/warn/error`. Splitting one-per-check is mechanical.
- **Syntax split:** Neovim syntax files use `vim.api.nvim_buf_add_highlight` or treesitter highlight queries. Split by group prefix.
- **Tmux test pattern:** `if vim.fn.empty(vim.env.TMUX) == 1 then pending('tmux required') end` at the top of relevant `it()`.
- **Git worktree test pattern:** `local tmpdir = vim.fn.tempname(); vim.fn.system({'git', 'init', tmpdir})` — fixture scaffolding.

## Gotchas

- `health.lua` line 226 interpolates `full_path` into `find` — verify `full_path` source; if user-controlled, this is high-risk.
- `health.lua` line 111 greps for the `claude` process — depends on running processes; tests should mock or skip.
- Refactoring `syntax.lua` can subtly break highlight ordering; verify with `:source` on a sample shotfile in headless mode.

## Links

- Spec: `../../../spec.md`
- Phase plan: `./plan.md`
- Neovim health-check docs: `:help vim.health`
