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

| Shotfile | Theme |
|---|---|
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

## Task Workflow (Simple Shots)

1. **Create a shot bead** (`bd create --type=shot --parent=<shots-epic-id> --title="..."`)
2. **Claim it** (`bd update <id> --status=in_progress`)
3. **Execute** the task directly
4. **Close the bead** (`bd close <id> --reason="what was done"`)
5. **Bump version** (`bash ~/.claude/shooter/scripts/shell/shooter_increment-version.sh patch`)
6. **Commit** with a clear message including the version
7. **Push** and `bd sync` — work is not done until pushed

## Question Workflow

1. **Answer** the question directly in the conversation
2. **Persist** the Q&A to `.shooter/q-and-a.md` — append the question and a concise answer summary
3. **No bead, no version bump, no commit required** — the Q&A file gets committed with the next task naturally

The Q&A file is included in agent instruction files (AGENTS.md, CLAUDE.md, GEMINI.md) when non-empty, giving future agents context from past questions.

## Complex Shot Workflow (Escalate to Epic)

When a shot requires 3+ steps or architectural decisions:

1. **Create an epic** under the theme: `bd create --type=epic --parent=<theme-id> --title="<shot title>"`
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
