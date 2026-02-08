# Artifact Persistence Rules

All AI output of lasting value must be persisted to the filesystem. Conversation context is ephemeral; files are permanent.

## Artifact Locations

| Artifact Type     | Location                            |
|-------------------|-------------------------------------|
| Research reports  | `.shooter/research/<topic-slug>.md` |
| Project plans     | `.shooter/plans-shooter/<plan-name>.md` |
| Decision log      | `.shooter/decisions.md`             |
| Learning records  | `.shooter/context-ai-learnings.md`  |
| Q&A records       | `.shooter/q-and-a.md`               |

## Rules

- **Decisions must be saved** — after closing a bead that involved decisions, record them in `.shooter/decisions.md`
- **Learnings must be saved** — if you discover something important about the project, add it to `.shooter/context-ai-learnings.md`
- **Research must be saved** — if you researched something, write it to `.shooter/research/`
- **Check existing research first** — before starting any research, read `.shooter/research/` to see if a similar topic was already researched. If it exists, build on it (update or reference) instead of duplicating. If not, create a new document.
- **Multi-document research uses subfolders** — if a research topic produces multiple documents, store them in `.shooter/research/<topic-slug>/` with an `index.md` or descriptive filenames. Single-document research stays as `.shooter/research/<topic-slug>.md`.
- **Plans must be saved** — execution plans go under `.shooter/plans-shooter/<plan-name>.md`
- **CLI plan mode uses `.shooter/plans-shooter/`** — write plans to `.shooter/plans-shooter/` instead of the CLI's default global directory
- Use kebab-case for all file slugs: `topic-name.md`, not `topicName.md`
- Keep artifacts self-contained — a reader should understand without conversation context
- Update existing artifacts rather than creating duplicates

## Context Files

| File | Owner | Priority |
|------|-------|----------|
| `.shooter/context-human-learnings.md` | Human only | **Higher** — takes precedence if conflicts |
| `.shooter/context-ai-learnings.md` | AI agents | Lower |

- **AI must never edit** `.shooter/context-human-learnings.md` — it is read-only for AI
- Update `.shooter/context-ai-learnings.md` when discovering: build commands, test patterns, deployment procedures, project conventions, error patterns

## Decision Tracking

After closing a bead that involved meaningful decisions, **prepend** to `.shooter/decisions.md` (newest first):

```markdown
## YYYY-MM-DD HH:MM: <short decision title>

**Decision:** <what was decided>
**Reason:** <why this choice over alternatives>
```

Record architecture/pattern choices, technology selections, and non-obvious trade-offs. Skip trivial implementation details. Before making a significant decision, read `.shooter/decisions.md` to check if already decided.
