---
name: feats-refactor
description: Refactor shooter.nvim — split overgrown modules, audit shell-out security, raise test coverage measurably; tests-first to lock current behavior.
status: in_progress
created: 2026-04-26
approved: 2026-04-26
tier: large
tier_source: deterministic
---

# Spec — feats-refactor

## Objective

Improve internal quality of `shooter.nvim` along three axes without changing user-visible behavior:

1. **Structural clarity** — split modules whose size or grab-bag responsibilities make them hard to read or modify (top offenders: `lua/shooter/plans/metaplan.lua` 1584 LOC, `lua/shooter/commands.lua` 1190, `lua/shooter/core/shot_actions.lua` 795). Splits are driven by cohesion, not a blanket line cap.
2. **Security** — audit the 110 shell-out call sites (`vim.fn.system`, `vim.fn.systemlist`, `io.popen`, `vim.fn.jobstart`) and path-handling in shotfile / plan rename ops. Fix any unescaped interpolation, quoting bugs, or path-traversal risks.
3. **Test coverage** — establish a luacov baseline, then raise coverage to **80% absolute** (or baseline +10pp if baseline already ≥ 80%). Tests are written **before** any refactor so behavior is locked in; refactors must keep them green.

Out of scope: new features, plugin API changes, performance optimization, dependency upgrades.

## Tech Stack

- **Runtime:** Neovim ≥ 0.10 (Lua 5.1 / LuaJIT semantics)
- **Test runner:** plenary.nvim's busted-compatible `:PlenaryBustedDirectory tests/`
- **Test bootstrap:** `tests/minimal_init.lua` (clones plenary into `/tmp/nvim/site/pack` on first run)
- **Coverage:** `luacov` — auto-installed via `tests/minimal_init.lua` (luarocks-style bootstrap into `/tmp/nvim/site` on first test run, mirrors plenary's pattern). Target: **80% total, absolute**.
- **CI:** existing `.github/workflows/` (verify before/after each phase)
- **Lint:** `luacheck` if present (audit during phase 0)

## Commands

```bash
# Run full test suite
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

# Coverage (after Phase 0 lands luacov wiring)
nvim --headless -u tests/minimal_init.lua -c "lua require('luacov')" -c "PlenaryBustedDirectory tests/ ..."
luacov                              # generate luacov.report.out
awk '/^Total/ {print $4}' luacov.report.out   # current %

# Security audit greps
grep -rn 'vim\.fn\.system\|io\.popen\|vim\.fn\.jobstart' lua/
grep -rn 'shellescape\|fnameescape' lua/

# Per-file LOC inventory
find lua -name '*.lua' -exec wc -l {} + | sort -rn
```

## Project Structure

Current top-level layout (preserved):

```
lua/shooter/
  analytics/       # 4 files,  ~ 760 LOC
  commands.lua     # 1190 LOC — split candidate (group by sub-area)
  core/            # 12 files, ~3500 LOC (shot_actions.lua 795 — split candidate)
  health.lua       # 369 LOC — split candidate (per check section)
  help.lua         # 314 LOC — likely fine; review only
  plans/           # metaplan.lua 1584 — primary split candidate
  session/         # 6 files, ~1054 LOC — already cohesive
  syntax.lua       # 513 LOC — split by syntax group
  telescope/       # pickers.lua 620, helpers.lua 529 — split candidates
  tmux/            # 7 files, ~1280 LOC (toggle_panes 377 — review)
  tools/           # 7 files (git_worktree.lua 378 — review)
  utils.lua        # contains shell-out helpers — security focal point
```

Refactored layout: same top-level dirs; oversized files split into a sibling sub-module folder where it improves clarity. Example:

```
plans/metaplan.lua  →  plans/metaplan/init.lua, plans/metaplan/parse.lua, plans/metaplan/render.lua, plans/metaplan/categories.lua, plans/metaplan/numbering.lua
```

The `init.lua` re-exports the public surface so existing `require('shooter.plans.metaplan')` callers keep working.

## Code Style

- Lua 5.1 / LuaJIT — no Lua 5.3 features.
- Module pattern: `local M = {} ... return M`. Public functions on `M`; private `local function`.
- Shell-outs **must** use `vim.fn.shellescape` for any interpolated path or user input. Prefer the table form of `vim.fn.system({...})` when feasible — it bypasses the shell.
- Path joins: `vim.fs.joinpath` (Neovim ≥ 0.10) over manual `..` concatenation.
- No new globals. Existing implicit globals (if any) are flagged in phase 0 and either localized or documented.
- One module per file; `init.lua` files re-export only — no logic.

## Testing Strategy

**Tests-first invariant:** every refactor task is gated by a tests-locked behavior baseline. Phase order:

1. **Phase 0 — baseline & tooling** — wire luacov, record baseline %, audit security surface, audit oversized files. Output: a written report committed to `docs/plans/0001-feats-refactor/baseline.md`. No source changes.
2. **Phase 1 — characterization tests** — for each file slated for split or security fix, write tests that pin current observable behavior (input → output, side effects on a tmpdir/scratch buffer). Coverage of touched modules must reach **≥ 80%** before refactor begins.
3. **Phases 2..N — refactor + security fixes** — one cohesive split or security cluster per phase. Pre-phase: tests green. Post-phase: tests still green, no behavior change, no public-API change.
4. **Phase final — coverage check & cleanup** — re-run luacov, confirm target met, remove any dead code surfaced by the refactor.

Test conventions:
- File pattern: `tests/<area>/<module>_spec.lua` (mirrors source layout).
- Each `_spec.lua` declares `describe()`/`it()` blocks; each `it` is one observable behavior.
- Side-effect tests use `vim.fn.tempname()` for scratch dirs; teardown in `after_each`.
- No mocks for `vim.fn.system` unless the test is asserting the *command string* — prefer real subprocess against a controlled fixture dir.
- Per `CLAUDE.md`: every change must be verified — tests run before commit, no exceptions.

## Boundaries

**In scope:**
- File splits driven by cohesion. Soft cap: **350 LOC**. Files over 350 must split unless explicitly granted an exception in `baseline.md` (cohesive-unit rationale required).
- **Security audit — wider scope:**
  - Shell-out injection: every `vim.fn.system`, `vim.fn.systemlist`, `io.popen`, `vim.fn.jobstart`. Audit and fix unescaped path/user-input interpolation; prefer table-form `vim.fn.system({...})` to bypass the shell.
  - Path handling: every shotfile/plan rename/move site. Fix path-traversal and missing `fnameescape`.
  - Dynamic code execution: every `loadstring` / `load` / `dofile` / `loadfile` call. Audit input source; refuse if input is user-controlled.
  - Temp file handling: every `vim.fn.tempname()` / `os.tmpname()` / `/tmp/` write. Check for race conditions (TOCTOU), predictable names, missing cleanup, world-readable artifacts.
  - File permissions: every file/dir creation. Verify mode bits don't leak credentials or shotfile contents to other users.
- Adding `luacov` tooling via auto-install in `tests/minimal_init.lua` (mirrors plenary's bootstrap).
- Writing new characterization tests for any module being touched.
- CI: enforce 80% coverage as a regression gate (verify CI currently runs tests in Phase 0; if not, wire it).

**Out of scope:**
- Public Lua API changes (exported function names, signatures, return shapes).
- User-facing keymap changes, command renames, behavior changes.
- New features (any "while you're in there" feature additions go to a follow-up plan).
- Dependency upgrades (plenary, telescope, etc.).
- Performance optimization beyond what falls out of refactoring naturally.
- Migrating the test runner away from plenary.

**Backwards-compatibility contract:** every public `require('shooter.<path>')` that callers currently use must keep returning the same shape. When splitting `foo.lua` into `foo/init.lua + foo/x.lua + foo/y.lua`, `init.lua` re-exports.

## Success Criteria

```yaml
criteria:
  - description: Full test suite passes
    verify: |
      nvim --headless -u tests/minimal_init.lua \
        -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua', sequential = true}" \
        -c "qa!" 2>&1 | tee /tmp/feats-refactor-test.log
      ! grep -E 'Tests Failed|Errors *: *[1-9]' /tmp/feats-refactor-test.log
    expected_exit: 0

  - description: Coverage ≥ 80% (absolute, total) per luacov
    verify: |
      test -f luacov.report.out && \
        awk '/^Total/ {pct=$NF; gsub("%","",pct); exit !(pct+0 >= 80)}' luacov.report.out
    expected_exit: 0

  - description: No shell-out site interpolates an unescaped path
    verify: |
      ! grep -rnE "(vim\.fn\.system|io\.popen|vim\.fn\.jobstart)\(.*\.\..*\)" lua/ \
        | grep -vE "shellescape|fnameescape|^[^:]+:[0-9]+:\s*--|-- audited:"
    expected_exit: 0

  - description: No dynamic code execution from user-controlled input (loadstring/load/dofile/loadfile)
    verify: |
      ! grep -rnE "(loadstring|\bload\(|dofile|loadfile)" lua/ \
        | grep -vE "^[^:]+:[0-9]+:\s*--|-- audited:"
    expected_exit: 0

  - description: No source file in lua/ exceeds 350 LOC (soft cap; exceptions documented in baseline.md)
    verify: |
      over=$(find lua -name '*.lua' -exec wc -l {} + | awk '$1 > 350 && $2 != "total" {print $2}')
      allowed=$(awk '/^ALLOWED_LARGE_FILES:/{flag=1; next} /^$/{flag=0} flag{print $2}' \
                docs/plans/0001-feats-refactor/baseline.md 2>/dev/null || true)
      diff <(echo "$over" | sort) <(echo "$allowed" | sort) | grep -q '^<' && exit 1 || exit 0
    expected_exit: 0

  - description: CI workflow enforces test pass + 80% coverage gate
    verify: |
      grep -rE "(luacov|coverage).*(80|0\.80)" .github/workflows/ >/dev/null && \
      grep -rE "PlenaryBustedDirectory|busted" .github/workflows/ >/dev/null
    expected_exit: 0

  - description: Public module surface unchanged (smoke load every existing top-level require path)
    verify: |
      nvim --headless -u tests/minimal_init.lua \
        -c "luafile docs/plans/0001-feats-refactor/scripts/smoke_require.lua" \
        -c "qa!"
    expected_exit: 0
```

## Open Questions

All resolved at approval time (2026-04-26):

1. **Coverage target:** 80% absolute (total, per luacov). Phase 0 measures baseline; if baseline already ≥ 80%, target raises by 10 percentage points.
2. **Coverage tooling:** auto-install `luacov` via `tests/minimal_init.lua` (mirrors plenary bootstrap pattern).
3. **LOC soft cap:** 350 lines. Files over 350 must split unless `baseline.md`'s `ALLOWED_LARGE_FILES:` entry justifies the exception.
4. **Phase granularity:** per-area (plans, telescope, core, tmux, analytics, tools, root). `/hal:plan` decides exact area boundaries.
5. **Security scope — wider:** shell-out injection, path-traversal in rename/move, dynamic code execution (`loadstring`/`load`/`dofile`/`loadfile`), temp-file races + permissions, file mode bits on artifact creation. See Boundaries → In scope.
6. **CI gate:** yes — Phase 0 verifies CI currently runs tests; the final phase wires `luacov ≥ 80%` as a CI regression gate (failing the workflow if coverage drops).
