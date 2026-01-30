# AI Agent Configuration

Source: ~/a/ai v0.1.0 | Generated: 2026-01-30

> This file uses `@includes` to reference context files.
> Edit `.ai-context.md` for project-specific context.

## Project Context

@.ai-context.md

## Codebase Overview

GSD codebase analysis (read when needed):

- `.planning/codebase/STACK.md` — STACK
- `.planning/codebase/ARCHITECTURE.md` — ARCHITECTURE
- `.planning/codebase/STRUCTURE.md` — STRUCTURE
- `.planning/codebase/CONVENTIONS.md` — CONVENTIONS
- `.planning/codebase/CONCERNS.md` — CONCERNS
- `.planning/codebase/INTEGRATIONS.md` — INTEGRATIONS
- `.planning/codebase/TESTING.md` — TESTING

## Rules

@~/a/ai/rules/core/coding-standards.md
@~/a/ai/rules/core/security.md
@~/a/ai/rules/core/commit-conventions.md
@~/a/ai/rules/core/multi-agent-conventions.md
@~/a/ai/rules/core/shot-workflow.md

## Commands

- `/review.md` — @~/a/ai/commands/review.md
- `/refactor.md` — @~/a/ai/commands/refactor.md
- `/test.md` — @~/a/ai/commands/test.md
- `/debug.md` — @~/a/ai/commands/debug.md

## Session Close Protocol

Before ending any session:

```bash
git status              # Check what changed
git add <files>         # Stage code changes
git commit -m "..."     # Commit code
git push                # Push to remote
```
