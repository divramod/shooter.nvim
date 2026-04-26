---
name: coverage-gate-ci-cleanup
description: Push coverage to ≥ 80% global; wire CI luacov gate; final security verification; cleanup.
status: approved
phase_id: 005
depends_on: ["001", "002", "003", "004"]
wave: 3
created: 2026-04-26
tier: large
tier_source: deterministic
---

# Phase 005 — Coverage Gate, CI, Cleanup

## Overview

Per-area phases each enforce ≥ 80% on their touched files. This phase ensures the **global** total reaches 80%, wires the CI regression gate, runs every Success Criterion in `spec.md`, and removes any dead code surfaced during refactoring.

## Architecture

- New / modified `.github/workflows/test.yml` (or wherever tests run) invokes the busted directory + luacov + asserts ≥ 80% as a CI step. Failing keeps PRs red.
- A new `scripts/check_coverage.sh` is the canonical gate, callable from CI and locally.
- Final-cleanup commits remove any dead code or unreachable branches surfaced by coverage analysis.

## Approach

1. Run global luacov; identify modules below 80%.
2. Add tests until global total ≥ 80% (excluding `ALLOWED_LARGE_FILES` exceptions documented in `baseline.md`).
3. Wire CI: ensure `PlenaryBustedDirectory` runs on every push/PR; ensure `scripts/check_coverage.sh` runs after and fails the workflow when total < 80%.
4. Run every Success Criterion in `spec.md` end-to-end via `hal lifecycle masterplan ship --dry-run`. All six criteria must pass.
5. Remove dead code, cleanup any orphan files/shims left from refactors.

## Tasks

- [ ] **T001** — Identify modules below 80%
  - **Acceptance:** A short report `phases/005-coverage-gate-ci-cleanup/coverage_gap.md` lists every file below 80% with: current %, lines uncovered, and which (if any) belong on the exception list vs. need new tests.
  - **Verify:** Report file exists and references current `luacov.report.out`.
  - **Files:** `docs/plans/0001-feats-refactor/phases/005-coverage-gate-ci-cleanup/coverage_gap.md`
  - **Size:** S
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

- [ ] **T002** — Add tests to push global total ≥ 80%
  - **Acceptance:** Each gap from T001 is closed by new test cases or moved to the exception list with explicit rationale.
  - **Verify:** `awk '/^Total/ {pct=$NF; gsub("%","",pct); exit !(pct+0 >= 80)}' luacov.report.out`.
  - **Files:** Various `tests/**/*_spec.lua`, possibly `docs/plans/0001-feats-refactor/baseline.md`
  - **Size:** L
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

- [ ] **T003** — `scripts/check_coverage.sh`
  - **Acceptance:** A repo-root script runs the test+coverage pipeline and exits non-zero when global total < 80%.
  - **Verify:** `bash scripts/check_coverage.sh; echo $?` is 0 today; manually editing the threshold to 99 returns non-zero.
  - **Files:** `scripts/check_coverage.sh`
  - **Size:** S
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

- [ ] **T004** — Wire CI workflow with test + coverage gate
  - **Acceptance:** `.github/workflows/test.yml` (or existing equivalent) runs `:PlenaryBustedDirectory tests/` and `bash scripts/check_coverage.sh` on push/PR. Workflow fails if either fails. The workflow's grep test in Success Criteria #5 passes.
  - **Verify:** `grep -rE "(luacov|coverage).*(80|0\.80)" .github/workflows/`; `grep -rE "PlenaryBustedDirectory|busted" .github/workflows/`.
  - **Files:** `.github/workflows/test.yml`
  - **Size:** M
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

- [ ] **T005** — Final security verification
  - **Acceptance:** Every Success Criterion 3, 4 in `spec.md` passes (no unescaped shell-out interpolation; no user-controlled dynamic exec).
  - **Verify:** Run the verify commands from `spec.md § Success Criteria` for criteria #3 and #4; both exit 0.
  - **Files:** None (verification only); possibly small fixes if a residual finding is uncovered
  - **Size:** S
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

- [ ] **T006** — Cleanup
  - **Acceptance:** No orphan files, no dead modules, no leftover shims pointing at deleted paths. `lua/` walks cleanly.
  - **Verify:** `find lua -name '*.lua' -empty` returns no results; `grep -rn 'TODO.*refactor' lua/` no leftover TODOs from this run.
  - **Files:** Various
  - **Size:** S
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

- [ ] **T007** — Run full Success Criteria from spec.md
  - **Acceptance:** All six criteria in `spec.md` pass when run via `hal lifecycle masterplan ship --dry-run` (or the equivalent `bash scripts/verify-success.sh`).
  - **Verify:** `bash docs/plans/0001-feats-refactor/scripts/verify-success.sh; echo $?` is 0.
  - **Files:** —
  - **Size:** S
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

## Risks

- Pushing the global to 80% may surface modules that *cannot* be tested headlessly (some `vim.api.nvim_*` UI calls). Acceptable per `baseline.md` exception list, but a small number of exceptions is expected.
- CI workflow changes can break the existing CI; T004 should run on a feature branch and verify in PR before merge.
- `verify-success.sh` is generated by `hal lifecycle spec render-verify`; T007 may need to re-run that command after spec edits land in earlier phases.

## Open Questions

1. Does `scripts/check_coverage.sh` belong at repo root or under `docs/plans/0001-feats-refactor/scripts/`? Default: repo root — it's a permanent quality tool, not a one-off plan artifact.
2. Should the CI gate be advisory at first (warning, not failure) for one cycle? Default: no — the spec says enforce.
