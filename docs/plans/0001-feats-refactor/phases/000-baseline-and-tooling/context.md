---
name: baseline-and-tooling-context
description: Phase 000 context — files, patterns, and gotchas for baseline + tooling work.
---

# Context — Phase 000

## Files to Load

- `tests/minimal_init.lua` — currently bootstraps plenary; will be extended for luacov
- `.github/workflows/` — read to determine current CI test-run state
- All files in `lua/shooter/` (read-only) — surveyed for security inventory + LOC inventory

## Patterns

- **Idempotent bootstrap:** mirror plenary's pattern at the top of `tests/minimal_init.lua` — `if vim.fn.isdirectory(path) == 0 then vim.fn.system({...clone...}) end`. Apply identically for luacov.
- **Coverage scope:** `.luacov` should set `include = { "lua/shooter/" }` and `exclude = { "tests/", "scripts/" }` so coverage measures only product code.
- **Security inventory format:** one line per site, format `<file>:<line> | <kind> | <risk> | <notes>`. Easy to grep and to migrate into per-area phase tasks.

## Gotchas

- luacov writes `luacov.stats.out` per-process; if tests run in parallel via `:PlenaryBustedDirectory`, stats can get corrupted. Use `sequential = true` in the busted config until stable.
- The `.luacov` config file location: project root, not `tests/`. luacov searches CWD; tests run from project root.
- `find lua -name '*.lua' -exec wc -l {} +` includes a `total` line; filter via `$2 != "total"`.

## Links

- luacov: <https://keplerproject.github.io/luacov/>
- plenary busted: <https://github.com/nvim-lua/plenary.nvim/blob/master/TESTS_README.md>
