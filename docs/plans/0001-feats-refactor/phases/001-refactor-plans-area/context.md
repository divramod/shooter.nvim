---
name: refactor-plans-area-context
description: Phase 001 context — files, patterns, gotchas for the plans/ refactor.
---

# Context — Phase 001

## Files to Load

- `lua/shooter/plans/metaplan.lua` — primary refactor target (1584 LOC)
- `lua/shooter/plans/init.lua` — public surface entry; check shape before splitting
- All existing `tests/plans/*_spec.lua` — to avoid duplication
- `docs/plans/0001-feats-refactor/baseline.md § Security Inventory` (subset for `plans/`)
- `docs/plans/0001-feats-refactor/phases/001-refactor-plans-area/seams.md` — written in T001

## Patterns

- **Re-export-only init.lua:** `return require('shooter.plans.metaplan.init')` from `metaplan.lua` shim, OR delete `metaplan.lua` and rely on Lua's `package.path` resolution of `metaplan/init.lua` for `require('shooter.plans.metaplan')` (idiomatic Lua).
- **Path canonicalization for rename:** `local p = vim.fn.fnamemodify(input, ":p"); if p:find("%.%.") then error(...) end`. Validate that the canonical path is still under the expected root (string-prefix check).
- **Test fixture pattern for plans:** create a tmp dir via `vim.fn.tempname()`, populate with fake plan folders / masterplan.md, run the operation, assert filesystem state, teardown in `after_each`.

## Gotchas

- `metaplan.lua` is the largest file in the repo — opening it in nvim/Read will cost context. Prefer reading by line ranges based on the seam map written in T001.
- The plans area contains plan-numbering logic that must be deterministic; tests must control `vim.fn.glob` results (or use real fixtures, never the live `docs/plans/`).
- Plenary's `:PlenaryBustedDirectory tests/plans/` runs in alpha order; tests that mutate shared state must teardown thoroughly.

## Links

- Spec: `../../../spec.md`
- Masterplan: `../../../masterplan.md`
- Phase plan: `./plan.md`
