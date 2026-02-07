# Quality Gates

Mandatory checks and thresholds before commits and merges.

## Pre-Commit Checks

Before EVERY commit, all configured checks MUST pass. The specific commands depend on the project's toolchain, but the gates are universal:

1. **Format** — code formatting matches project config
2. **Lint** — no lint errors or warnings
3. **Typecheck** — no type errors (for typed languages)
4. **Build** — project builds successfully

Never commit if any check fails — fix the issue first.

## Test Requirements

- 80%+ test coverage for new code (unit tests)
- 80%+ test coverage for new pages/components (E2E tests)
- Never delete existing tests — tests can only be added or updated
- Never skip tests (`.skip()`, `test.skip()`, `@Disabled`, etc.)
- E2E tests must cover all target browsers/platforms
- Clean up test resources after runs (no orphan processes)

## Immutable Config Rules

These configurations are project-level decisions and must not be changed by AI agents:

1. Do not modify linter configuration
2. Do not modify formatter configuration
3. Do not modify type-checker configuration
4. Do not suppress lint warnings — fix them
5. Do not suppress format warnings — fix them
6. Do not suppress type errors — fix them
7. Do not ignore build warnings — builds must be clean

## Git Gates

- Always push after committing (no local-only commits)
- Never use interactive git flags (`-i`)
- Never force push to main/master
- Never skip git hooks (`--no-verify`)
- One logical change per commit

## Coverage Enforcement

When a project defines coverage thresholds:

- Respect the configured minimums
- New code must meet or exceed the project threshold
- Never lower coverage thresholds to make builds pass
- If coverage drops, add tests before merging
