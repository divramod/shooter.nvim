# Shot Workflow

Shots are instructions sent by the user from nvim to the AI agent's terminal.

## How Shots Arrive

The user writes a shot in nvim, then sends it as a temporary file reference (e.g., `@/path/to/shot-N-timestamp.md`). The agent reads the file and executes.

## Core Principle

Shotfiles are **read-only input**. Never modify the source shotfile.

## Step 1: Classify the Shot

Read the shot and classify it into one of three categories:

- **Task** — do something simple (< 3 steps: implement, fix, refactor, create, update)
- **Question** — answer something (explain, research, advise, compare)
- **Complex** — larger work (3+ steps, architectural decisions, multi-file changes) → escalate to an epic

## Step 2: Identify the Theme

Every shot arrives from a shotfile that belongs to a theme. The `# context` section at the bottom of each shot includes the feature name (e.g., "shooter ai", "shooter cli").

**Shotfile → Theme mapping:**

`_project` is the default meta-theme for cross-cutting work that doesn't belong to any specific theme.

| Shotfile | Theme |
|---|---|
| `.shooter/shotfiles/_project.md` | _project |
| `.shooter/shotfiles/ai.md` | shooter/ai |
| `.shooter/shotfiles/cli.md` | shooter/cli |
| `.shooter/shotfiles/tui.md` | shooter/tui |
| `.shooter/shotfiles/lib.md` | shooter/lib |
| `.shooter/shotfiles/daemon.md` | shooter/daemon |
| `.shooter/shotfiles/api.md` | shooter/api |
| `.shooter/shotfiles/web.md` | shooter/web |
| `.shooter/shotfiles/nvim.md` | shooter/nvim |
| `.shooter/shotfiles/app-ios.md` | shooter/app-ios |
| `.shooter/shotfiles/app-android.md` | shooter/app-android |

**Finding the shots epic**: Each theme has a permanent shots epic (e.g., `ai-shots`, `cli-shots`). To find it:

```bash
# Find the theme bead by title
bd list --type=theme --json | grep -o '"id":"[^"]*"' | ...

# Find the shots epic under that theme
bd children <theme-id> --type=epic --json | grep "shots"
```

If the theme or shots epic cannot be found, fall back to creating a plain `--type=task` bead without a parent.

## Step 3: Read Theme Context

If the `# context` section includes a `- Theme context:` or `- Theme README:` line, read that file before executing. It contains module-specific documentation (codebase summary or README) that helps you understand the theme's purpose, architecture, and conventions. This is on-demand context — only read it when referenced, and use it to inform your execution.

## Task Workflow (Simple Shots — 1-2 steps)

1. **Create a shot bead** (`bd create --type=shot --parent=<shots-epic-id> --title="..." --description="<shot content>" --labels="type:issue:shot,theme:<slug>"`)
   The `--description` MUST contain the shot content (the user's instruction from the shotfile). This preserves what was requested — the temp file will be deleted, and without the description, future agents and the human in `bv` only see the title.
   The `--labels` MUST include `type:issue:shot,theme:<slug>` (e.g., `type:issue:shot,theme:ai`) to enable `bv` label filtering.
2. **Claim it** (`bd update <id> --status=in_progress`)
3. **Execute** the task directly
4. **Close the bead** (`bd close <id> --reason="what was done"`)
5. **Record decisions** — if the work involved meaningful decisions, prepend them to `.shooter/decisions.md`
6. **CRITICAL — Commit, push, sync in ONE call** using `shooter_commit.sh`:
   ```bash
   bash <shooter-dir>/scripts/shell/shooter_commit.sh \
     --message "type(scope): description" \
     --beads "<bead-id>" \
     --co-author "<model> <noreply@anthropic.com>" \
     -- <files...>
   ```
   **NEVER run git add, git commit, bd sync, git push as separate commands.** The script handles ALL of it: version bump → bd sync → git add (files + beads + VERSION) → git commit (with trailers) → bd sync → git push → git status. Flags: `--no-push`, `--no-version-bump`.

## Task Workflow (Multi-Step Shots — 3+ steps)

When a shot requires 3 or more distinct steps (but isn't large enough to escalate to an epic):

1. **Create a shot bead** (`bd create --type=shot --parent=<shots-epic-id> --title="..." --description="<shot content>" --labels="type:issue:shot,theme:<slug>"`)
   The `--description` MUST contain the shot content (the user's instruction from the shotfile). This preserves what was requested — the temp file will be deleted, and without the description, future agents and the human in `bv` only see the title.
   The `--labels` MUST include `type:issue:shot,theme:<slug>` (e.g., `type:issue:shot,theme:ai`) to enable `bv` label filtering.
2. **Claim it** (`bd update <id> --status=in_progress`)
3. **Create child beads for each step** BEFORE starting work:
   ```bash
   bd create --type=task --parent=<shot-id> --title="Step 1: ..." --labels="type:issue:task,theme:<slug>"
   bd create --type=task --parent=<shot-id> --title="Step 2: ..." --labels="type:issue:task,theme:<slug>"
   bd create --type=task --parent=<shot-id> --title="Step 3: ..." --labels="type:issue:task,theme:<slug>"
   ```
4. **For each step:** mark in_progress → execute → mark closed with reason
5. **Close the parent shot bead** when all children are done
6. **Record decisions** — if the work involved meaningful decisions, prepend them to `.shooter/decisions.md`
7. **CRITICAL — Commit, push, sync in ONE call** using `shooter_commit.sh` (same as simple workflow step 6)

**Why:** If Claude crashes mid-work, `bd list --status=in_progress` shows exactly where to resume. TaskCreate is ephemeral (lost on crash) — beads persist across sessions. Use TaskCreate for UI spinners only, never as a substitute for beads.

## Question Workflow

1. **Answer** the question directly in the conversation
2. **Persist** the Q&A to `.shooter/q-and-a.md` — **prepend** (newest first) below the `# Q&A` heading. Format:
   ```
   ## YYYY-MM-DD HH:MM: <short question title>
   ```
   Include full timestamp so newest questions are always at the top and easy to spot.
3. **No bead, no version bump, no commit required** — the Q&A file gets committed with the next task naturally

The Q&A file is included in agent instruction files (AGENTS.md, CLAUDE.md, GEMINI.md) when non-empty, giving future agents context from past questions.

## Complex Shot Workflow (Escalate to Epic)

When a shot requires 3+ steps or architectural decisions:

1. **Create an epic** under the theme: `bd create --type=epic --parent=<theme-id> --title="<shot title>" --description="<shot content>" --labels="type:epic,theme:<slug>"`
   Include the shot content in the epic description so the scope and original request are preserved. Set `--labels="type:epic,theme:<slug>"` for `bv` filtering.
2. **Enter plan mode** or run `shooter:plan-epic` to break it into child issues
3. **Execute** via `shooter:execute-epic` or manually work through child issues
4. The original shot is NOT tracked as a `--type=shot` — it becomes an epic directly

## Rules

- Never write back to the shotfile — it is immutable input
- One bead per task shot minimum — the bead is the agent's memory of the work
- Shots use `--type=shot` and are parented to their theme's shots epic
- If a shot is blocked, note the blocker in the bead and ask the user
- Make atomic commits as you go for multi-step work
- If you cannot determine the theme, create a plain task bead without a parent

## Shot Sources

- Temporary files from nvim plugin: `@/path/to/shot-N-timestamp.md`
- Shotfiles in `.shooter/shotfiles/`
- Inline instructions from the user in the terminal

## Querying Shots

```bash
bd list --type=shot                          # All shots across all themes
bd list --type=shot --parent=<shots-epic-id> # Shots for a specific theme
bd epic status <shots-epic-id>               # Shot completion rate for a theme
```
