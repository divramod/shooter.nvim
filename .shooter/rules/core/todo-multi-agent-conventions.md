# Multi-Agent Conventions

Rules for coordinating work across AI coding agents. All agents operating in repos that use the ai ruleset MUST follow these conventions.

---

## GSD Workflow Integration

This project uses GSD (Get Shit Done) for task tracking and project management. GSD provides phases, plans, todos, and persistent state across sessions.

---

## 1. Agent Identification

Every agent session should be identifiable. Use the Co-Authored-By trailer in commits to identify which agent performed the work.

| Agent | Co-Authored-By |
|-------|----------------|
| Claude Code (Opus 4.5) | `Claude Opus 4.5 <noreply@anthropic.com>` |
| Claude Code (Opus 4.6) | `Claude Opus 4.6 <noreply@anthropic.com>` |
| Claude Code (Sonnet 4) | `Claude Sonnet 4 <noreply@anthropic.com>` |
| Claude Code (Sonnet 5) | `Claude Sonnet 5 <noreply@anthropic.com>` |
| OpenCode (GPT-5.2 Codex) | `GPT-5.2 Codex <noreply@openai.com>` |
| OpenCode (GPT-5.3 Codex) | `GPT-5.3 Codex <noreply@openai.com>` |
| OpenCode (Gemini 3 Pro) | `Gemini 3 Pro <noreply@google.com>` |
| Gemini CLI | `Gemini CLI <noreply@google.com>` |
| Codex CLI | `Codex CLI <noreply@openai.com>` |
| Human | N/A |

---

## 2. Commit Convention

Every commit should follow conventional commits with a `Co-Authored-By` trailer for AI-authored commits.

Format:
```
<type>(<scope>): <description> (<version>)

- <beads ids>
- <shot number>
Co-Authored-By: <Agent Name> <noreply@provider.com>
```

Example:
```
feat(ai/rules): add typescript standards

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

Rules:
- `<type>` follows conventional commits: feat, fix, refactor, docs, chore, test, ci, perf, style
- `<scope>` is the area of the codebase affected
- `<version>` is the new version after the change (patch bump for AI commits, central version file in .shooter/VERSION)
- `<shot number>` is the shot associated with the work (if applicable)
- `<beads ids>` are the IDs of the beads that contributed to the work
- `Co-Authored-By` is required for all AI-generated commits

---

## 3. Session Handoff Protocol

### Ending a session

1. Complete current work
2. Update beads
3. Commit changes with clear message
4. Push: `git push`

### Starting a session

1. Pull latest: `git pull`
2. Check GSD progress: `/gsd:progress`
3. Find ready work: `/gsd:check-todos` or `/gsd:ready`
4. Continue from where previous session left off

---

## 4. Progress Tracking with GSD

AI agents should use GSD commands for progress tracking:

- `/gsd:progress` — Check project progress and current state
- `/gsd:check-todos` — List pending todos and select one to work on
- `/gsd:add-todo` — Capture ideas or tasks from conversation context
- `/gsd:pause-work` — Create context handoff when pausing mid-phase
- `/gsd:resume-work` — Resume work from previous session

### When working on a task:

1. **Check status**: `/gsd:progress`
2. **Select work**: `/gsd:check-todos`
3. **Execute**: Do the work
4. **Commit**: Atomic commits as you go

---

## 5. Context Rot Prevention

These rules prevent stale context and duplicated sources of truth across multi-agent workflows.

1. **Single source of truth**: GSD owns progress and state. Plan files own design. Never duplicate progress in both.
2. **No orphan work**: Capture significant work items with `/gsd:add-todo` immediately when you discover something that needs doing.
3. **File findings immediately**: When you discover bugs, inconsistencies, or improvements during reviews — either fix them or add a todo.
4. **Session handoff protocol**: Always follow the ending/starting procedures in section 3. No silent session exits.
5. **Plan file is a blueprint**: After implementation starts, plan files are only updated for design changes.

---

## 6. Consistency Across Repos

All repositories under `~/a/` should use consistent tooling configuration.

1. **GSD initialization**: Projects using GSD should have `.planning/` directory with GSD state
2. **Context file wiring**: Every repo has `.ai-context-human.md` and `.ai-context-ai.md` referenced in context files (CLAUDE.md, GEMINI.md, AGENTS.md)

---

## 7. Shot Workflow

See `rules/core/shot-workflow.md` for full rules.

Key points: shotfiles are **read-only input**. Track execution via GSD or git commits, never write back to the shotfile.

---

## 8. Artifact Persistence

See `rules/core/artifact-persistence.md` for full rules.

Key points: all AI output of lasting value must be persisted to the filesystem. Research goes to `plans/research/`, plans to `plans/<cli-name>/`. Different CLIs write to separate subdirectories to avoid conflicts.

---

## 9. Plan Mode Workflow

When working with plans, use GSD for execution tracking:

### For new projects:
- `/gsd:new-project` — Initialize project with deep context gathering

### For phases:
- `/gsd:discuss-phase` — Gather phase context through adaptive questioning before planning
- `/gsd:plan-phase` — Create detailed execution plan for a phase
- `/gsd:execute-phase` — Execute plans with atomic commits

**Recommended workflow**: discuss → plan → execute

### For quick tasks:
- `/gsd:quick` — Execute quick task with GSD guarantees but skip optional agents
