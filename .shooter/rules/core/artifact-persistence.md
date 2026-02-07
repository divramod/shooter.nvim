# Artifact Persistence Rules

Rules for persisting AI-generated artifacts so they are discoverable and durable.

## Core Principle

All AI output of lasting value must be persisted to the filesystem. Conversation context is ephemeral; files are permanent.

## Artifact Locations

| Artifact Type     | Location                            | Example                                 |
|-------------------|-------------------------------------|-----------------------------------------|
| Research reports  | `.shooter/research/<topic-slug>.md` | `.shooter/research/auth-providers.md`   |
| Project plans     | `.shooter/plans-ai/<plan-name>.md`  | `.shooter/plans/web-app/init-plan.md`   |
| Decision log      | `.shooter/decisions.md`             | Centralized, newest first               |
| Learning records  | `.shooter/context-ai-learnings.md`  | `.shooter/context-ai-learnings.md`      |
| Q&A records       | `.shooter/q-and-a.md`               | `.shooter/q-and-a.md`                   |

## Rules

- **Decisions must be saved** — after closing a bead that involved decisions, record them in `.shooter/decisions.md`
- **Learnings must be saved** — if you discover something important about the project, add it to `.shooter/context-ai-learnings.md`
- **Research must be saved** — if you researched something, write it to `.shooter/research/`
- **Plans must be saved** — execution plans go under `plans-ai/<plan-name>.md`
- Use kebab-case for all file slugs: `topic-name.md`, not `topicName.md`
- Include a YAML frontmatter block with `date`, `author`, and `status` fields
- Keep artifacts self-contained — a reader should understand without conversation context
- Update existing artifacts rather than creating duplicates

## Naming Conventions

- Topic slugs should be descriptive: `react-state-management.md` not `research-1.md`
- Plan names should reflect the phase or goal: `phase-2-auth.md` not `plan.md`
- Avoid generic names — specificity aids discovery

## Discoverability

- Artifacts should be findable by browsing the directory structure
- Use clear directory hierarchies over flat file dumps
- Cross-reference related artifacts with relative links
- The file path itself should hint at the content

## Context Files

Each project has two context files for AI agents:

| File                                  | Owner      | Priority   | Purpose                                                             |
|---------------------------------------|------------|------------|---------------------------------------------------------------------|
| `.shooter/context-human-learnings.md` | Human only | **Higher** | Human-written project context, preferences, critical instructions   |
| `.shooter/context-ai-learnings.md`    | AI agents  | Lower      | AI-discovered patterns, learned preferences, project-specific notes |

### Priority Rules

1. **Human context takes precedence** — if instructions conflict, follow `.shooter/context-human-learnings.md`
2. **AI must never edit** `.shooter/context-human-learnings.md` — it is read-only for AI
3. **AI can update** `.shooter/context-ai-learnings.md` when discovering important project patterns

### When AI Should Update `.shooter/context-ai-learnings.md`

Update the AI context file when you discover:
- Build commands or scripts specific to the project
- Testing patterns or test commands
- Deployment procedures
- Project-specific conventions not in global rules
- Frequently needed context that would otherwise require re-discovery
- Error patterns or troubleshooting steps
- Any insight that would help future AI agents work more effectively on the project

### Format

Keep entries concise and actionable:

```markdown
## Build

- `pnpm build` — production build
- `pnpm dev` — development server

## Testing

- `pnpm test` — run all tests
- `pnpm test:e2e` — end-to-end tests

## Other commands
- `pnpm lint` — run linter
- `pnpm format` — format code

## Error Patterns

- If you see `Error: Cannot find module 'xyz'`, it means you need to run `pnpm install` first
- If you see `SyntaxError: Unexpected token`, check if it's a missing dependency or a version mismatch
```

## Decision Tracking

After closing a bead that involved meaningful decisions, record them in `.shooter/decisions.md`. This file is included in agent instruction files, giving future agents context about past choices.

### When to Record

Record a decision when it would help future agents avoid re-litigating settled choices:
- Architecture or pattern choices (e.g., "chose hooks over polling for file change detection")
- Technology or library selections (e.g., "chose SQLite over PostgreSQL for beads")
- Approach decisions when alternatives existed (e.g., "single file over per-decision files")
- Design trade-offs that weren't obvious (e.g., "sonnet over haiku for setup skill")

Do NOT record trivial implementation details (variable names, formatting choices, obvious fixes).

### Format

**Prepend** new decisions below the `# Decisions` heading (newest first). Use this format:

```markdown
## YYYY-MM-DD HH:MM: <short decision title>

**Decision:** <what was decided>
**Reason:** <why this choice over alternatives>
```

Optionally add `**Alternatives:**` or `**Context:** <bead-id>` if they add value.

### Reference Before Deciding

Before making a significant decision, read `.shooter/decisions.md` to check if a similar decision was already made. Follow existing decisions unless there's a strong reason to change course.
