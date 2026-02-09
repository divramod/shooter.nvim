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
- After ANY correction from the user: update `.shooter/context.md` with the pattern
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

1. **Plan First**: Write plan to `.shooter/plans/<YYYY-MM-DD>_<HH-MM>_<short-description>.md` with checkable items. **CRITICAL**: All plans MUST be persisted — CLI plan mode must write to `.shooter/plans/` instead of the CLI's default global directory.
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to `.shooter/plans/<plan>.md`
6. **Capture Lessons**: Update `.shooter/context.md` after corrections

## Banner Requirements

Every `sho:` command and agent must display a banner as its first output. The banner shows the **shooter framework version** (not the project version) and the model.

**The current shooter version is: `{{shooter:version}}`**

**Format:**
```
**`sho:<name>`** · **shooter v{{shooter:version}}** · model: **<model>**
```

- `<name>` — the command name (e.g., `prj-setup-infrastructure`, `gtd-epic-plan`, `cfg-make-healthy`)
- `shooter v{{shooter:version}}` — the shooter framework version (compiled into this file, do NOT read `.shooter/VERSION` for banners)
- `<model>` — the model you are running on (e.g., `opus`, `sonnet`)

**IMPORTANT:** `.shooter/VERSION` is the **project's** version, not the shooter version. Never use it for `sho:` command banners.

**When creating new commands:** Add a `## Banner` section as the first step in `<process>`:
```markdown
## Banner
Output: **`sho:<command-name>`** · **shooter v{{shooter:version}}** · model: **<model>**
```

## Command Logging

Every shooter command invocation must be logged for usage tracking and repo registry.

**Banner step addition:** Before reading `.shooter/VERSION`, run:
```bash
bash <shooter-dir>/scripts/shell/sho_util-log-command.sh "<command-name>" --model "<model>"
```

Where `<shooter-dir>` is `~/.claude/shooter` (Claude), `~/.gemini/shooter` (Gemini), or the equivalent for other CLIs. `<model>` is the model you are running on (e.g., `opus`, `sonnet`, `gemini-2.5-pro`). The CLI is auto-detected from the script's install path — no `--cli` flag needed. This:
1. Appends an entry to `.shooter/command-log.jsonl` (timestamp, command, CLI, model)
2. Registers/updates the repo in `~/.config/shooter/repos.json` (global registry)

The registry enables `sho:self-update` to batch-update all repos with latest rules.

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.

## On-Demand Context Files

These files are NOT loaded at startup to keep context lean. Read them when relevant:

| File | When to Read |
|------|-------------|
| `.shooter/context.md` | At session start; build commands, CLI notes, patterns |
| `.shooter/decisions.md` | Before making architectural decisions |
| `.shooter/q-and-a.md` | Before answering questions; check if already answered |
| `.shooter/codebase/_project/SUMMARY.md` | When exploring codebase or planning changes |
