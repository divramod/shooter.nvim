# Shooter Framework Glossary

Standard terminology used across shooter commands, agents, workflows, and documentation.

| Term | Meaning |
|------|---------|
| shooter | AI workflow orchestration framework installed into CLI directories |
| theme | Top-level grouping in a project (e.g., `api`, `web`, `tui`). Maps to a code directory and shotfile |
| epic | A body of work under a theme, tracked through lifecycle statuses |
| shot | An ad-hoc task sent from nvim to an AI agent via a shotfile |
| bead | A single issue/task/bug/feature tracked by the beads system (`bd` CLI) |
| wave | A group of issues within an epic that can execute in parallel |
| phase | A sequential stage within multi-phase work |
| agent | A specialized AI subagent spawned via Task tool (e.g., `shooter-executor`, `shooter-codebase-mapper`) |
| mapper | A `shooter-codebase-mapper` agent that analyzes code and writes structured documents |
| scope | The target of a codebase mapping: `_project` (whole repo) or a theme slug |
| orchestrator | The main agent context that spawns and coordinates subagents |
| command | A markdown instruction file in `ai/commands/` invoked as `sho:<name>` |
| workflow | A multi-step process definition in `ai/workflows/` referenced by commands |
| rule | A prose document in `ai/rules/core/` compiled into agent instruction files |
| agent file | Auto-generated instruction file: CLAUDE.md, AGENTS.md, or GEMINI.md |
| shotfile | A per-theme markdown file in `.shooter/shotfiles/` where shots are written |
| shots epic | A permanent epic under each theme that collects all ad-hoc shots |
| slug | A short kebab-case identifier for a theme (e.g., `ai`, `cli`, `app-ios`) |
| distro | Distribution of shooter artifacts to CLI directories |
| CLI directory | Where a CLI stores its config: `~/.claude/`, `~/.gemini/`, `~/.config/opencode/`, etc. |
| ensure script | An idempotent shell script prefixed `sho_ensure-` that creates/fixes state safely |
| prefixed output | Script output convention: lines start with `ok:`, `skip:`, `error:`, `created:`, etc. |
| model profile | Configuration (`quality`/`balanced`/`budget`) controlling which AI model agents use |
| context file | `.shooter/context.md` — persistent notes compiled into agent instruction files |
| decisions log | `.shooter/decisions.md` — record of architectural and design decisions |
