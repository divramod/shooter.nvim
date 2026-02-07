# Deterministic Execution

Maximize determinism in skills, commands, and workflows by moving logic into scripts.

## Principle

AI agents are non-deterministic — the same instruction can produce different behavior across runs, models, and context sizes. Shell scripts are deterministic — same input, same output, every time. For critical paths like setup, onboarding, and configuration, non-determinism causes frustration and erodes trust.

**Rule:** When creating or editing a skill, command, or workflow, identify every step that can be solved deterministically and extract it into a shell script. The AI should only handle steps that genuinely require non-deterministic reasoning: asking the user questions, interpreting ambiguous context, or making judgment calls.

## What Belongs in Scripts

- File existence checks and migrations
- Directory creation and cleanup
- Configuration file reading, writing, and validation
- Version bumping and formatting
- Git operations (stage, commit, push)
- Output formatting and summaries
- Detection and discovery (themes, dependencies, tools)
- Any logic with clear if/then/else branches

## What Stays with the AI

- Asking the user for input (AskUserQuestion, conversational prompts)
- Interpreting ambiguous or context-dependent situations
- Deciding between approaches when requirements are unclear
- Presenting options and recommendations to the user
- Parsing script output to determine next action (simple routing: `ok:` → skip, `missing:` → ask)

## Script Design for Skills

Scripts called from skills should follow this contract:

1. **Prefixed output** — start every line with a status word: `ok:`, `skip:`, `created:`, `error:`, `missing:`, `detected:`
2. **Exit codes** — 0 for success, 1 for usage error, 2 for precondition failure
3. **Idempotent** — safe to run multiple times with the same result
4. **Accept `--repo-root`** — never assume the working directory
5. **Self-contained** — handle edge cases internally (missing files, empty values, migration from old paths)

The AI's role is reduced to: run the script → read the prefix → route to the next action.

## Applying This Rule

When you write a new skill or modify an existing one:

1. List every step in the skill
2. For each step, ask: "Can this produce the same output for the same input without AI reasoning?"
3. If yes → it must be a script. Create `shooter_<action>.sh` in `ai/scripts/shell/`
4. If no → keep it as an AI instruction, but minimize the AI's scope (e.g., "ask the user X, then pass the answer to script Y")
5. The skill's instructions should read like a routing table: run script → parse prefix → decide next script or user interaction
