# Beads Workflow

Beads (`bd`) is the issue tracking system that serves as **persistent memory** for AI agents across sessions.

## Why Beads Matter

Every bead you create becomes searchable context for future sessions. When you close a bead with a reason, that reason persists — the next agent (or the same agent in a new session) can run `bd ready` or `bd list` to understand what was done before and what's pending. The user can browse this history in `bv` (beads TUI viewer).

## 3-Level Hierarchy: Theme → Epic → Issue

Beads uses a parent-child hierarchy to organize work:

```
Theme (--type=theme)              Top-level grouping (e.g., myproject/api, myproject/web)
├── Epic (--type=epic)            Body of work under a theme
│   ├── Task (--type=task)        Planned work item
│   ├── Bug (--type=bug)          Defect to fix
│   ├── Feature (--type=feature)  New capability
│   └── Shot (--type=shot)        Ad-hoc task from nvim shotfile
└── Shots Epic (<slug>-shots)     Permanent epic collecting all ad-hoc shots
    ├── Shot: "Add context files"
    └── Shot: "Fix rules generation"
```

## Type System

**Built-in types:** `task`, `bug`, `feature`, `chore`, `epic`

**Custom types (configured by `shooter:setup`):** `theme`, `shot`

| Type | Purpose | Parent |
|---|---|---|
| `theme` | Top-level grouping (project-specific, defined in `.shooter/themes.json`) | None |
| `epic` | Body of work, planned or shots collection | Theme |
| `task` | Planned work item | Epic |
| `bug` | Defect to fix | Epic |
| `feature` | New capability to add | Epic |
| `shot` | Ad-hoc task from nvim shotfile | Shots epic |

## Custom Statuses

**Built-in:** `open`, `in_progress`, `blocked`, `deferred`, `closed`

**Custom (configured by `shooter:setup`):** `discussed`, `planned`, `executing`, `verifying`

**Epic lifecycle:** `open` → `discussed` → `planned` → `executing` → `verifying` → `closed`

## Quick Reference

### Theme CRUD

```bash
bd create --type=theme --title="<alias>/<theme>"                # Create theme
bd list --type=theme                                           # List all themes
bd show <theme-id>                                             # Show theme details
bd children <theme-id>                                         # List epics under theme
bd update <theme-id> --title="new title"                       # Rename theme
```

### Epic CRUD

```bash
bd create --type=epic --parent=<theme-id> --title="Auth System"  # Create epic
bd list --type=epic --parent=<theme-id>                          # Epics under a theme
bd show <epic-id>                                                # Show epic details
bd children <epic-id>                                            # Issues under epic
bd epic status <epic-id>                                         # Epic progress
bd update <epic-id> --status=planned                             # Update status
bd update <epic-id> --design="Decision: use JWT tokens"          # Record decisions
bd update <epic-id> --notes="Research: compared 3 providers"     # Record research
bd update <epic-id> --acceptance="Must pass auth integration tests"  # Set criteria
bd close <epic-id> --reason="All child issues complete"          # Close epic
```

### Issue CRUD

```bash
bd create --type=task --parent=<epic-id> --title="Implement login"  # Create issue
bd create --type=bug --parent=<epic-id> --title="Fix token expiry"  # Create bug
bd create --type=shot --parent=<shots-epic-id> --title="Quick fix"  # Create shot
bd show <issue-id>                                                   # Show details
bd update <issue-id> --status=in_progress                            # Claim work
bd close <issue-id> --reason="Implemented with tests"                # Close
bd close <id1> <id2> <id3> --reason="Batch complete"                 # Close multiple
```

### Dependencies & Labels

```bash
bd dep add <issue-id> <depends-on-id>       # Add dependency
bd dep tree <issue-id>                       # Show dependency tree
bd label add <issue-id> "wave:1"             # Add wave label
bd label add <issue-id> "autonomous:true"    # Mark autonomous
bd list --label="wave:1" --parent=<epic-id>  # Issues in wave 1
```

### Querying

```bash
bd ready                                     # Issues ready to work (no blockers)
bd list --status=open                        # All open issues
bd list --status=in_progress                 # Active work
bd list --type=shot                          # All shots across themes
bd list --type=epic --parent=<theme-id>      # Epics under a theme
bd list --parent=<epic-id>                   # All issues under an epic
bd search "auth"                             # Full-text search
bd blocked                                   # Show blocked issues
bd stats                                     # Project statistics
```

## Label Conventions

- `wave:1`, `wave:2`, `wave:3` — parallel execution groups within an epic
- `autonomous:true` / `autonomous:false` — checkpoint control for executors
- `gap-closure` — issues created from verification gap analysis

## Shooter Commands Reference

These commands orchestrate beads operations with workflow logic:

| Command | Purpose |
|---|---|
| `shooter:configure-beads` | One-time setup: creates themes + shots epics |
| `shooter:add-theme` | Create a new theme with auto shots epic |
| `shooter:show-theme` | Display theme with its epics |
| `shooter:add-epic` | Create epic under a theme |
| `shooter:show-epic` | Display epic with child issues |
| `shooter:add-issue` | Create issue under an epic |
| `shooter:show-issue` | Display issue details |
| `shooter:discuss-epic` | Gray area discussion, write decisions to design field |
| `shooter:plan-epic` | Research → plan → check loop, creates child issues |
| `shooter:execute-epic` | Wave-based parallel execution of child issues |
| `shooter:verify-work` | UAT + diagnosis + gap planning |
| `shooter:resume-work` | Context restoration from beads state |
| `shooter:progress` | Dashboard with progress bars and routing |

## Parent-Child Gotchas

Creating parent-child relationships in beads has edge cases. Follow these patterns:

**Preferred: `--parent` flag on `bd create`** (generates dotted IDs, always works):
```bash
bd create --type=epic --title="My Epic"                    # → sho-abc
bd create --type=task --parent=sho-abc --title="Task 1"    # → sho-abc.1 ✓
bd create --type=task --parent=sho-abc --title="Task 2"    # → sho-abc.2 ✓
```

**Fallback: `bd dep add` for cross-hash IDs** (when `--parent` fails):
```bash
bd create --type=epic --title="Epic"   # → sho-abc
bd create --type=task --title="Task"   # → sho-xyz
bd dep add sho-abc sho-xyz --type parent-child
```

Note: `bd dep add X Y --type parent-child` means "X depends on Y" internally, which makes Y the parent and X the child. The error messages from bd suggest the correct command syntax — follow them.

**Avoid:**
- `bd edit` — opens $EDITOR, blocks AI agents. Use `bd update` instead.
- `bd create --id=X --parent=Y` — cannot combine these flags.
- `bd update <id> --parent <new-parent>` — same validation issues as `bd dep add`.

## Creating Good Beads

- **Title**: Short, imperative (e.g., "Add boundaries rule file")
- **Reason on close**: Describe what was accomplished, not just "done" — this is the memory future agents will read
- **Priority**: 0=critical, 1=high, 2=medium (default), 3=low, 4=backlog
- **Design field**: Record architectural decisions on epics
- **Notes field**: Store research findings on epics
- **Acceptance field**: Define done criteria on epics and issues
- **Description/body-file**: Execution prompts for issues (the plan the executor follows)

## Session Completion

When ending a work session, ALL of these must happen:

1. Close finished beads with descriptive reasons
2. Record any meaningful decisions to `.shooter/decisions.md` (see Artifact Persistence rules)
3. Create beads for any remaining/discovered work
4. `bd sync` to export changes
5. `git push` — work is NOT complete until pushed
6. Verify: `git status` must show "up to date with origin"

**CRITICAL**: Never stop before pushing. Never say "ready to push when you are" — YOU must push.
