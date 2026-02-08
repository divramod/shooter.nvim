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

**Custom types (configured by `sho:prj-setup-infrastructure`):** `theme`, `shot`

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

**Custom (configured by `sho:prj-setup-infrastructure`):** `discussed`, `planned`, `executing`, `verifying`

**Epic lifecycle:** `open` → `discussed` → `planned` → `executing` → `verifying` → `closed`

## Quick Reference

### Theme CRUD

```bash
bd create --type=theme --title="<alias>/<theme>" --labels="type:theme,theme:<slug>"  # Create theme
bd list --type=theme                                                                 # List all themes
bd show <theme-id>                                                                   # Show theme details
bd children <theme-id>                                                               # List epics under theme
bd update <theme-id> --title="new title"                                             # Rename theme
```

### Epic CRUD

```bash
bd create --type=epic --parent=<theme-id> --title="Auth System" --labels="type:epic,theme:<slug>"  # Create epic
bd list --type=epic --parent=<theme-id>                                                            # Epics under a theme
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
bd create --type=task --parent=<epic-id> --title="Implement login" --labels="type:issue:task,theme:<slug>"  # Create issue
bd create --type=bug --parent=<epic-id> --title="Fix token expiry" --labels="type:issue:bug,theme:<slug>"  # Create bug
bd create --type=shot --parent=<shots-epic-id> --title="Quick fix" --labels="type:issue:shot,theme:<slug>"  # Create shot
bd show <issue-id>                                                   # Show details
bd update <issue-id> --status=in_progress                            # Claim work
bd close <issue-id> --reason="Implemented with tests"                # Close
bd close <id1> <id2> <id3> --reason="Batch complete"                 # Close multiple
bd comments add <issue-id> "verification passed"                        # Add comment
```

### Dependencies & Labels

```bash
bd dep add <issue-id> <depends-on-id>       # Add dependency
bd dep tree <issue-id>                       # Show dependency tree
bd label add <issue-id> "plan:wave:1"             # Add wave label
bd label add <issue-id> "plan:autonomous:true"    # Mark autonomous
bd list --label="plan:wave:1" --parent=<epic-id>  # Issues in wave 1
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

Labels use a four-namespace taxonomy. Every label is prefixed with its namespace.

Full reference: `docs/beads-labels-and-types-system.md`

### Namespace: `type:` -- Type Labels

Auto-applied at creation time, maps to the bead's `issue_type` field.

| Label | Maps to |
|-------|---------|
| `type:theme` | `--type=theme` |
| `type:epic` | `--type=epic` |
| `type:issue:task` | `--type=task` |
| `type:issue:bug` | `--type=bug` |
| `type:issue:feature` | `--type=feature` |
| `type:issue:shot` | `--type=shot` |
| `type:issue:chore` | `--type=chore` |

### Namespace: `theme:` -- Theme Labels

Required on every bead. One per bead. The slug comes from the shotfile-to-theme mapping (e.g., `ai`, `cli`, `web`).

| Bead Type | Required Labels | Example |
|-----------|----------------|---------|
| Theme | `type:theme,theme:<slug>` | `--labels="type:theme,theme:ai"` |
| Epic | `type:epic,theme:<slug>` | `--labels="type:epic,theme:ai"` |
| Task/Bug/Feature/Shot | `type:issue:<kind>,theme:<slug>` | `--labels="type:issue:task,theme:ai"` |

When working under an epic, the parent relationship already provides epic context -- no separate `epic:` label needed.

### Namespace: `plan:` -- Workflow Labels

Used by agents to organize and control execution flow within epics.

- `plan:wave:1`, `plan:wave:2`, `plan:wave:3` -- parallel execution groups within an epic
- `plan:phase:1`, `plan:phase:2` -- sequential phases for multi-phase work
- `plan:autonomous:true` / `plan:autonomous:false` -- checkpoint control for executors
- `plan:gap-closure` -- issues created from verification gap analysis
- `plan:todo` -- marks issues needing attention

### Namespace: `meta:` -- Analysis Metadata

Used for categorization, severity, and historical tracking.

- `meta:concern` -- flags a concern on the bead
- `meta:severity:critical`, `meta:severity:high`, `meta:severity:medium`, `meta:severity:low` -- severity levels
- `meta:category:<name>` -- categorization (e.g., `meta:category:security`, `meta:category:performance`)
- `meta:history:<tag>` -- historical markers (e.g., `meta:history:migrated`, `meta:history:split-from`)

### Label Governance

Labels are governed by `.shooter/labels.json` which has two sections: `"shooter"` (generated vocabulary from template + themes) and `"project"` (user-extended labels). The shooter section is regenerated by `sho_ensure-labels.sh`; the project section is preserved across updates. Inline labels (from `--labels` flag) are applied per-bead at creation time.

### Querying by Label

```bash
bd list --label="theme:ai"                        # All beads in the ai theme
bd list --label="theme:cli" --status=open         # Open beads in cli theme
bd list --label="plan:wave:1" --parent=<epic-id>  # Wave 1 issues in an epic
bd list --label="plan:gap-closure"                # All gap-closure issues
```

## Shooter Commands Reference

These commands orchestrate beads operations with workflow logic:

| Command | Purpose |
|---|---|
| `sho:cfg-beads` | One-time setup: creates themes + shots epics |
| `sho:gtd-theme-add` | Create a new theme with auto shots epic |
| `sho:gtd-theme-show` | Display theme with its epics |
| `sho:gtd-epic-add` | Create epic under a theme |
| `sho:gtd-epic-show` | Display epic with child issues |
| `sho:gtd-issue-add` | Create issue under an epic |
| `sho:gtd-issue-show` | Display issue details |
| `sho:gtd-epic-discuss` | Gray area discussion, write decisions to design field |
| `sho:gtd-epic-plan` | Research → plan → check loop, creates child issues |
| `sho:gtd-epic-execute` | Wave-based parallel execution of child issues |
| `sho:gtd-verify-work` | UAT + diagnosis + gap planning |
| `sho:gtd-resume-work` | Context restoration from beads state |
| `sho:prj-show-progress` | Dashboard with progress bars and routing |

## Parent-Child Relationships

**Always use `--parent` flag on `bd create`** (generates dotted IDs, most reliable):
```bash
bd create --type=epic --title="My Epic"                    # → sho-abc
bd create --type=task --parent=sho-abc --title="Task 1"    # → sho-abc.1 ✓
bd create --type=task --parent=sho-abc --title="Task 2"    # → sho-abc.2 ✓
```

**Fallback: `bd dep add` for cross-hash IDs** (when beads are already created separately):
```bash
bd create --type=epic --title="Epic"   # → sho-abc
bd create --type=task --title="Task"   # → sho-xyz
bd dep add sho-xyz sho-abc --type parent-child
# sho-xyz (child) depends on sho-abc (parent)
```

**Avoid:**
- `bd edit` — opens $EDITOR, blocks AI agents. Use `bd update` instead.
- `bd create --id=X --parent=Y` — cannot combine these flags.

## Creating Good Beads

Every bead should be self-contained — a human reading it in `bv` or an agent picking it up cold should understand what it is, why it exists, and (if closed) what was accomplished.

### Required Fields by Type

| Field | Shot | Task/Bug/Feature | Epic |
|-------|------|-------------------|------|
| **Title** | Short, imperative | Short, imperative | Short, descriptive |
| **Description** | Shot content (what was requested) | What to do + why | Scope + objectives |
| **Labels** | `type:issue:shot,theme:<slug>` | `type:issue:<kind>,theme:<slug>` | `type:epic,theme:<slug>` |
| **Close reason** | What was done + files touched | What was done + files touched | Summary + child issue count |
| **Acceptance** | — | Testable criteria | Epic-level done criteria |
| **Design** | — | — | Architecture decisions |
| **Notes** | — | — | Research findings |

### Description Rules

- **Every bead MUST have a description.** A title-only bead is invisible in `bv` and useless for context recovery.
- **Shots**: Copy the shot content (the user's instruction) into the description. This preserves what was requested after the temp file is deleted.
- **Tasks/Bugs/Features**: Include what to do and why. For planned issues (from `sho:gtd-epic-plan`), this is the execution prompt.
- **Epics**: Scope statement — what this body of work covers and what success looks like.
- Keep descriptions concise (3-10 lines). Link to related beads rather than embedding their full context.

### Close Reason Format

Close reasons are the primary memory artifact. Use this structure:

```
<What was accomplished — 1-2 sentences>. Key files: <paths>. <Verification result or notable decisions>.
```

Examples:
- Good: "Added JWT auth middleware at `src/middleware/auth.ts` with token validation and refresh. Tests pass (12/12). Chose RS256 over HS256 for key rotation support."
- Bad: "Done"
- Bad: "Implemented the feature"

### Priority

0=critical, 1=high, 2=medium (default), 3=low, 4=backlog. Use numbers only.
Never pass priority as text strings like "high", "medium", "low" — always use numbers 0-4 or P0-P4.

### Inline Updates

Use `bd update` with inline flags for quick field updates:
- `bd update <id> --description "long text"` — set or update description
- `bd update <id> --design "decisions..."` — record design decisions on epics
- `bd update <id> --notes "research..."` — record research findings on epics
- `bd comments add <id> "text"` — add comments (good for verification results)

## Session Completion

When ending a work session, ALL of these must happen:

1. Close finished beads with descriptive reasons
2. Record any meaningful decisions to `.shooter/decisions.md` (see Artifact Persistence rules)
3. Create beads for any remaining/discovered work
4. **CRITICAL — Commit, push, sync in ONE call** using `sho_util-commit.sh`:
   ```bash
   bash <shooter-dir>/scripts/shell/sho_util-commit.sh \
     --message "type(scope): description" \
     --beads "<bead-ids>" \
     --co-author "<model> <noreply@anthropic.com>" \
     -- <files...>
   ```
   **NEVER run git add, git commit, bd sync, git push as separate commands.** The script handles ALL of it: version bump → bd sync → git add (files + beads + VERSION) → git commit (with trailers) → bd sync → git push → git status.
5. Verify: output ends with `ok: committed and pushed` and `git status` shows "up to date with origin"

**CRITICAL**: Never stop before pushing. Never say "ready to push when you are" — YOU must push.
