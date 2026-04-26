---
name: coverage-gate-ci-cleanup-context
description: Phase 005 context — files, patterns, gotchas for coverage gate + CI + cleanup.
---

# Context — Phase 005

## Files to Load

- `docs/plans/0001-feats-refactor/baseline.md` — exception list source of truth
- `luacov.report.out` — generated; current global total
- `.github/workflows/*.yml` — existing CI definition
- `docs/plans/0001-feats-refactor/scripts/verify-success.sh` — generated from spec

## Patterns

- **CI gate pattern:** a single shell step `bash scripts/check_coverage.sh` that exits non-zero when below threshold. Easy to invoke locally and in CI; no GitHub-Actions-specific syntax in the gate logic.
- **Coverage gap closing:** prefer a few high-value tests over many trivial ones. Aim each new test at uncovered code paths surfaced by the coverage report.

## Gotchas

- Tests that depend on environment (tmux/git/claude binaries) must `pending()` rather than fail when the env is missing — CI runners may be minimal.
- `luacov.report.out` is gitignored typically; ensure CI runs the test step before the coverage check.
- The CI workflow can race on parallel jobs; if multiple jobs write `luacov.stats.out`, configure a single test job for now.

## Links

- Spec: `../../../spec.md`
- Phase plan: `./plan.md`
- luacov: <https://keplerproject.github.io/luacov/>
