---
name: feats-refactor-context
description: Cross-phase context for the feats-refactor masterplan.
---

# Context — feats-refactor

## Files to Load

- `docs/plans/0001-feats-refactor/spec.md` — authoritative requirements
- `docs/plans/0001-feats-refactor/baseline.md` — produced by Phase 000; coverage baseline, security inventory, allowed large-file list
- `tests/minimal_init.lua` — test bootstrap; modified in Phase 000 for luacov auto-install
- `lua/shooter/utils.lua` — central shell-out helpers; shared dependency for area refactors
- `.github/workflows/*.yml` — CI definition; touched in Phase 000 (read) and Phase 005 (write)
- `CLAUDE.md` — project-level instructions: verify your work, run tests before commit

## Patterns

- **Module split pattern:** when splitting `foo.lua` (>350 LOC) into `foo/`, the new `foo/init.lua` is *re-export-only* — no logic. All callers `require('shooter.foo')` continue working unchanged.
- **Shell-out hardening pattern:** prefer `vim.fn.system({"cmd", "arg1", arg2_user_input})` (table form, no shell) over string-form. When string-form is unavoidable, every interpolated path must go through `vim.fn.shellescape()`.
- **Path-handling pattern:** `vim.fs.joinpath(a, b)` over `a .. "/" .. b`. `vim.fn.fnamemodify(p, ":p")` to canonicalize before validation. Reject paths containing `..` after canonicalization.
- **Tests-first invariant:** every refactor task is preceded by a characterization-tests task in the same phase that brings the touched module(s) to ≥ 80% local coverage. Refactors run only after the tests are green.
- **Public-surface contract:** the public surface is everything reachable via `require('shooter.<path>')`. The `scripts/smoke_require.lua` produced in Phase 000 enumerates it; every phase's review checks the smoke loader still passes.

## Gotchas

- **plenary headless flakiness:** `:PlenaryBustedDirectory` sometimes hangs on `nvim --headless` exit. The sentinel pattern (`-c "qa!"` + log-grep for `Tests Failed`) is the canonical way to detect failures from CI/automation; relying on Neovim's exit code alone is unreliable.
- **`vim.fn.system` table form is Neovim ≥ 0.10.** Confirmed in Tech Stack; do not regress to ≤ 0.9 string form.
- **luacov + plenary integration:** `require('luacov')` must be called *before* the source module is `require`d, or coverage is missed. Pattern: load luacov in `tests/minimal_init.lua` *before* the `set rtp+=.` line.
- **`tests/minimal_init.lua` runs on every test invocation** including in CI; the luacov bootstrap must be idempotent and fast (skip-if-installed).
- **`commands.lua` re-entrancy:** the file registers user commands on Neovim startup. Splitting it must preserve registration order; `init.lua` must call submodules' setup functions in the original order.
- **Tests that shell out** (`tmux/*_spec.lua`, `tools/git_worktree_spec.lua`) only run when their respective tools are installed. Tests must `pending()` rather than fail when the tool is absent — otherwise CI breaks on minimal runners.

## Links

- Spec: [spec.md](spec.md)
- Masterplan: [masterplan.md](masterplan.md)
- Origin shotfile: `~/a/shooter.nvim/docs/shotfiles/feats.md` shot 43
- Test runner docs: <https://github.com/nvim-lua/plenary.nvim>
- luacov docs: <https://keplerproject.github.io/luacov/>
