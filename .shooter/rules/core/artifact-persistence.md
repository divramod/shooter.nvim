# Artifact Persistence Rules

All AI output of lasting value must be persisted to the filesystem. Conversation context is ephemeral; files are permanent.

## Artifact Locations

| Artifact Type     | Location                            |
|-------------------|-------------------------------------|
| Research reports  | `.shooter/research/<topic-slug>.md` |
| Project plans     | `.shooter/plans/<YYYY-MM-DD>_<HH-MM>_<short-description>.md` |
| Decision log      | `.shooter/decisions.md`     |
| Context (learnings + notes) | `.shooter/context.md` |
| Q&A records       | `.shooter/q-and-a.md`       |
| Glossary          | `.shooter/glossary.md`      |

## Rules

- **Decisions must be saved** — after closing a bead that involved decisions, record them in `.shooter/decisions.md`
- **Learnings must be saved** — if you discover something important about the project, add it to `.shooter/context.md`
- **Research must be saved** — if you researched something, write it to `.shooter/research/`
- **Check existing research first** — before starting any research, read `.shooter/research/` to see if a similar topic was already researched. If it exists, build on it (update or reference) instead of duplicating. If not, create a new document.
- **Multi-document research uses subfolders** — if a research topic produces multiple documents, store them in `.shooter/research/<topic-slug>/` with an `index.md` or descriptive filenames. Single-document research stays as `.shooter/research/<topic-slug>.md`.
- **Plans must be saved** — execution plans go under `.shooter/plans/<plan-name>.md`
- **CLI plan mode uses `.shooter/plans/`** — write plans to `.shooter/plans/` instead of the CLI's default global directory
- Use kebab-case for all file slugs: `topic-name.md`, not `topicName.md`
- Keep artifacts self-contained — a reader should understand without conversation context
- Update existing artifacts rather than creating duplicates

## Context Files

| File | Owner | Priority |
|------|-------|----------|
| `.shooter/context.md` (Human Notes section) | Human only | **Higher** — takes precedence if conflicts |
| `.shooter/context.md` (AI Learnings section) | AI agents | Lower |
| `.shooter/glossary.md` | Human (primary), AI may suggest additions | Compiled into agent files |

- **Human Notes section of `.shooter/context.md` is read-only for AI** — AI must never edit it
- Update AI Learnings section of `.shooter/context.md` when discovering: build commands, test patterns, deployment procedures, project conventions, error patterns
- `.shooter/glossary.md` contains project-specific terms and abbreviations. The human owns this file. AI agents may suggest new entries but should not add them without asking.

## Decision Tracking

After closing a bead that involved meaningful decisions, **prepend** to `.shooter/decisions.md` (newest first):

```markdown
## YYYY-MM-DD HH:MM: <short decision title>
**Theme:** <theme-slug>
**Decision:** <what was decided>
**Reason:** <why this choice over alternatives>
```

- **Theme** is required. Use the theme slug from the shotfile/bead context (e.g., `ai`, `cli`, `tui`). For project-wide decisions that don't belong to a specific theme, use `_project`.
- Record architecture/pattern choices, technology selections, and non-obvious trade-offs. Skip trivial implementation details.
- Before making a significant decision, read `.shooter/decisions.md` to check if already decided.
