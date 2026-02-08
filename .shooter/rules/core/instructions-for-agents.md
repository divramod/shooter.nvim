# Instructions for Claude

## Workflow Orchestration

### 1. Plan Mode Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately - don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- After ANY correction from the user: update `.shooter/context-ai-learnings.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes - don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests - then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Task Management

1. **Plan First**: Write plan to `.shooter/plans-shooter/<plan>.md` with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to `.shooter/plans-shooter/<plan>.md`
6. **Capture Lessons**: Update `.shooter/context-ai-learnings.md` after corrections

## Banner Requirements

Every command, skill, and agent must display a banner as its first output. The banner shows the shooter version and the model executing the task, giving the user immediate visibility into what's running.

**Format:**
```
**`shooter:<name>`** · **vX.Y.Z** · model: **<model>**
```

- `<name>` — the command/skill name (e.g., `setup`, `plan-epic`, `health`)
- `vX.Y.Z` — read from `.shooter/VERSION`
- `<model>` — the model actually executing: for skills with a `model:` frontmatter field, use that value (e.g., `sonnet`, `haiku`); for commands (which run on the orchestrator's model), output the model you are running on (e.g., `opus`, `sonnet`)

**When creating new commands:** Add a `## Banner` section as the first step in `<process>`:
```markdown
## Banner
Before doing ANY work, read `.shooter/VERSION` and output:
**`shooter:<command-name>`** · **vX.Y.Z** · model: **<model>**
```

**When creating new skills:** Add a `## Banner` section as the first step in `<process>`. Skills specify their model in YAML frontmatter (`model: sonnet`), so use that value:
```markdown
## Banner
Before doing ANY work, read `.shooter/VERSION` and output:
**`shooter:<skill-name>`** · **vX.Y.Z** · model: **<model>**
```

## Command Logging

Every shooter command and skill invocation must be logged for usage tracking and repo registry.

**Banner step addition:** Before reading `.shooter/VERSION`, run:
```bash
bash <shooter-dir>/scripts/shell/shooter_log-command.sh "<command-name>"
```

Where `<shooter-dir>` is `~/.claude/shooter` (Claude), `~/.gemini/shooter` (Gemini), or the equivalent for other CLIs. This:
1. Appends an entry to `.shooter/command-log.jsonl` (timestamp, command, CLI)
2. Registers/updates the repo in `~/.config/shooter/repos.json` (global registry)

The registry enables `shooter:update` to batch-update all repos with latest rules.

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.

## On-Demand Context Files

These files are NOT loaded at startup to keep context lean. Read them when relevant:

| File | When to Read |
|------|-------------|
| `.shooter/context-ai-learnings.md` | At session start; build commands, CLI notes, patterns |
| `.shooter/decisions.md` | Before making architectural decisions |
| `.shooter/q-and-a.md` | Before answering questions; check if already answered |
| `.shooter/codebase/_project/SUMMARY.md` | When exploring codebase or planning changes |
