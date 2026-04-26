# Baseline — feats-refactor (plan 0001)

Living document captured during Phase 000. Sections are filled in by Phase 000 tasks T001–T006.

## CI

**Source:** `.github/workflows/test.yml` (Phase 000 T001).

**Status:** CI **does** run tests on push and pull-request to `main` / `master`.

Salient details:

- Trigger: `push` / `pull_request` on `main` and `master`.
- Concurrency group cancels in-progress runs for the same ref.
- Matrix: Neovim `stable` and `nightly` (Ubuntu).
- Test runner: `plenary.test_harness.test_directory('tests/', {minimal_init = 'tests/minimal_init.lua', sequential = true})` (timeout 120s).
- Failure detection: greps test output for `^Failed :.*[1-9]` (Neovim's exit code is unreliable in headless).
- Linter: `luacheck` runs *after* tests with `continue-on-error: true` (advisory only — does not fail the build).

**Implications for Phase 005 (CI gate):**

- CI infrastructure is in place; T004 of Phase 005 only needs to add a coverage step + gate, not bootstrap a workflow.
- The test step already uses `sequential = true` — compatible with luacov's single-process expectation.
- The matrix runs Neovim stable + nightly. The luacov coverage gate should run on **stable only** to avoid double-counting and to keep the canonical baseline reproducible.
- `luacheck` is opportunistic; not in scope to make it strict in this plan, but flag for future hardening.

**No workflow changes required in Phase 000.** Phase 005 T004 will add a coverage step + gate.

## Coverage Baseline

> Filled in by Phase 000 T003. Will contain per-module + total coverage percentages from `luacov.report.out`.

## Security Inventory

> Filled in by Phase 000 T004. Will contain a line-by-line catalogue of:
>
> - Shell-out sites: `vim.fn.system`, `vim.fn.systemlist`, `io.popen`, `vim.fn.jobstart`
> - Path-handling sites: file/dir rename/move, untrusted path interpolation
> - Dynamic code execution: `loadstring`, `load(`, `dofile`, `loadfile`
> - Temp-file handling: `vim.fn.tempname`, `os.tmpname`, `/tmp/` writes
> - File-permission setters
>
> Format per row: `<file>:<line> | <kind> | <risk: high|med|low> | <notes>`.

## LOC Inventory

> Filled in by Phase 000 T005. Lists every file > 350 LOC with `kind: split-candidate | exception`.

## ALLOWED_LARGE_FILES

> Each entry is a file justified for exception from the 350-LOC soft cap. Format: `- <path>: <rationale>`. Empty until Phase 000 T005 / per-area phases populate it.
