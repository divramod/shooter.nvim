# Naming Conventions

Consistent naming across all shooter artifacts.

## Commands

**Format:** `sho:<namespace>-<verb>-<noun>` or `sho:<namespace>-<noun>-<verb>`

**File location:** `ai/commands/<namespace>-<name>.md` (flat, no subdirectories)

**Namespaces (6):**

| Namespace | Purpose | Examples |
|-----------|---------|----------|
| `help` | User guidance, onboarding | `help-show`, `help-do-tour` |
| `cfg` | Configuration, health | `cfg-beads`, `cfg-rules`, `cfg-make-healthy` |
| `gtd` | Task execution, epics, themes, issues | `gtd-epic-plan`, `gtd-issue-add`, `gtd-quick-execute` |
| `dev` | Repository operations | `dev-fork-repo`, `dev-commit-and-push` |
| `self` | Shooter self-management | `self-update`, `self-distribute-to-clis` |
| `prj` | Project-level operations | `prj-debug`, `prj-release`, `prj-map-codebase` |

**GTD entity pattern:** `gtd-<entity>-<action>` where entity is `epic`, `issue`, `theme`, `shot`, `todo`, `quick`.

**YAML frontmatter `name:` field** must match `sho:<filename-without-extension>`.

## Shell Scripts

**Format:** `sho_<category>-<name>.sh`

**File location:** `ai/scripts/shell/` (flat, no subdirectories)

**Categories (7):**

| Category | Purpose | Examples |
|----------|---------|----------|
| `ensure` | Idempotent setup/creation (safe to re-run) | `sho_ensure-rules.sh`, `sho_ensure-labels.sh` |
| `dist` | Distribution, installation, updates | `sho_dist-to-clis.sh`, `sho_dist-verify.sh` |
| `convert` | Format conversion between CLIs | `sho_convert-cmd-gemini.sh`, `sho_convert-agent-opencode.sh` |
| `util` | Shared utilities, helpers | `sho_util-commit.sh`, `sho_util-read-config.sh` |
| `arch` | History archaeology, import | `sho_arch-extract-commits.sh`, `sho_arch-mine-issues.sh` |
| `release` | Release lifecycle | `sho_release-create.sh`, `sho_release-changelog.sh` |
| `health` | Health checks, diagnostics | `sho_health-check.sh`, `sho_health-sync-rules-json.sh` |

**Script contract:** Prefixed output (`ok:`, `skip:`, `error:`, `created:`, `missing:`, `detected:`), exit codes (0=success, 1=usage, 2=precondition), idempotent, accepts `--repo-root`.

## Agents

**Format:** `shooter-<role>.md`

**File location:** `ai/agents/`

Agents are Task tool subagent types. Named by their functional role, not by namespace.

| Pattern | Examples |
|---------|----------|
| `shooter-<role>` | `shooter-executor`, `shooter-verifier`, `shooter-debugger` |
| `shooter-<entity>-<role>` | `shooter-epic-planner`, `shooter-epic-researcher` |
| `shooter-<domain>-<role>` | `shooter-codebase-mapper`, `shooter-history-interpreter` |

## Rules

**Format:** `<topic>.md` (kebab-case)

**File location:** `ai/rules/core/`

Rules are prose documents compiled into agent instruction files. Named by topic, not prefixed.

Examples: `commit-conventions.md`, `beads-workflow.md`, `naming-conventions.md`, `quality-gates.md`

## Workflows

**Format:** `<action>.md` (kebab-case, matches the process being orchestrated)

**File location:** `ai/workflows/`

Workflows describe multi-step processes used by commands. Named by the action they perform.

Examples: `plan-epic.md`, `execute-epic.md`, `map-codebase.md`, `verify-work.md`

## Templates

**Format:** `<target-filename>` (matches the file they generate)

**File location:** `ai/templates/`

Templates are copied or processed during setup. Named to match their output file.

Examples: `rules.json`, `config.yaml`, `labels.json`, `project-context.md`

## General Rules

- All filenames use **kebab-case** (lowercase, hyphen-separated)
- No underscores in filenames except the `sho_` script prefix
- No camelCase or PascalCase in filenames
- Prefer short, descriptive names — avoid redundant words
- `{{shooter:...}}` template variables use dot notation: `{{shooter:paths.forks}}`
