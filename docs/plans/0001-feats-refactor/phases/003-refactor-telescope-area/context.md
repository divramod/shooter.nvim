---
name: refactor-telescope-area-context
description: Phase 003 context — files, patterns, gotchas for telescope/ refactor.
---

# Context — Phase 003

## Files to Load

- `lua/shooter/telescope/pickers.lua` (620 LOC)
- `lua/shooter/telescope/helpers.lua` (529 LOC)
- Existing `tests/telescope/*_spec.lua`

## Patterns

- **Telescope picker stubbing:** create a `mock_telescope` table that captures `pickers.new` args; assert finder rows + previewer + sorter shape rather than UI behavior.
- **Sorter testing:** `helpers/sorter.lua` is pure (input list → sorted list). 100% coverage achievable — make this the test-coverage anchor.
- **Filter/format testing:** also pure; high coverage.

## Gotchas

- Telescope is loaded lazily by many configs; `require('telescope')` may fail in headless test env if not in rtp. Tests should `pcall(require, 'telescope')` and `pending()` if missing.
- `pickers.lua` likely uses `require('telescope.actions')` and other internal modules — bumping telescope version may break tests.

## Links

- Spec: `../../../spec.md`
- Phase plan: `./plan.md`
- Telescope API: <https://github.com/nvim-telescope/telescope.nvim/blob/master/developers.md>
