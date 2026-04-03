# Architecture

**Analysis Date:** 2026-04-03

## Pattern Overview

**Overall:** Neovim plugin following the standard `lua/` module pattern with a namespace-based command system and layered submodule architecture.

**Key Characteristics:**
- Single entry point (`lua/shooter/init.lua`) with `setup()` initialization pattern
- Command-driven architecture: all user interactions go through Neovim user commands registered in `lua/shooter/commands.lua`
- Tmux as the primary IPC mechanism for sending prompts to AI coding agents running in adjacent terminal panes
- Provider abstraction layer for multi-AI support (Claude, OpenCode, Codex, Gemini, Copilot)
- Two config systems: Lua-based (`config.lua`) for plugin options and YAML-based (`ext_config.lua`) for user-facing display/behavior settings
- Telescope integration for all picker/selection UIs

## Layers

**Plugin Entry (init + commands):**
- Purpose: Bootstrap the plugin, register commands and keymaps
- Location: `lua/shooter/init.lua`, `lua/shooter/commands.lua`, `lua/shooter/keymaps.lua`
- Contains: `setup()` function, ~80+ user command registrations organized by namespace (Shotfile, Shot, Tmux, Subproject, Tool, Cfg, Analytics, Help, Nav, Repo)
- Depends on: All submodules (lazy-loaded via `require()`)
- Used by: Neovim runtime (user calls `:ShoXxx` commands or uses keymaps)

**Core Layer (business logic):**
- Purpose: Shot and file management, the domain model
- Location: `lua/shooter/core/`
- Contains: Shot detection/parsing (`shots.lua`), file CRUD (`files.lua`), movement between folders (`movement.lua`, `move_picker.lua`), renaming (`rename.lua`), renumbering (`renumber.lua`), templates (`templates.lua`), project detection (`project.lua`), cross-repo operations (`repos.lua`), shot actions (`shot_actions.lua`, `shot_delete.lua`, `shot_move.lua`), greenkeep (`greenkeep.lua`), external config (`ext_config.lua`)
- Depends on: `utils.lua`, `config.lua`
- Used by: Commands layer, Telescope pickers, Tmux operations

**Tmux Layer (AI communication):**
- Purpose: Send text to tmux panes running AI agents, manage pane lifecycle
- Location: `lua/shooter/tmux/`
- Contains: Pane detection (`detect.lua`), text sending (`send.lua`, `keys.lua`), message building (`messages.lua`), pane creation (`create.lua`), high-level operations (`operations.lua`), toggle panes (`toggle_panes.lua`, `config_panes.lua`), shell interaction (`shell.lua`), pane watching (`watch.lua`), hidden session management (`hidden_session.lua`)
- Depends on: Core layer, Providers, Config
- Used by: Commands layer (send/queue commands)

**Provider Layer (AI abstraction):**
- Purpose: Abstract different AI coding agents behind a common interface
- Location: `lua/shooter/providers/`
- Contains: Registry and detection (`init.lua`), provider implementations: `claude.lua`, `opencode.lua`, `codex.lua`, `gemini.lua`, `copilot.lua`
- Depends on: Tmux send module
- Used by: Tmux operations layer

**Telescope Layer (UI):**
- Purpose: All picker/selection UIs for browsing shots, shotfiles, and sessions
- Location: `lua/shooter/telescope/`
- Contains: Main pickers (`pickers.lua`), actions (`actions.lua`), helpers (`helpers.lua`), previewers (`previewers.lua`), toggle panes picker (`toggle_panes_picker.lua`), help picker (`picker_help.lua`)
- Depends on: Core layer, Session module, telescope.nvim
- Used by: Commands layer

**Session Layer (state persistence):**
- Purpose: Persist and manage telescope picker state (filters, sort, folder visibility) per repo
- Location: `lua/shooter/session/`
- Contains: Session lifecycle (`init.lua`), storage (`storage.lua`), defaults (`defaults.lua`), filter logic (`filter.lua`), sort logic (`sort.lua`), session picker (`picker.lua`)
- Depends on: Core layer (ext_config for paths)
- Used by: Telescope pickers

**Supporting Modules:**
- `lua/shooter/analytics/` - Shot counting, report generation, charts
- `lua/shooter/queue/` - Shot queue management (queue shots for batch sending)
- `lua/shooter/inbox/` - Import tasks from external markdown inbox files
- `lua/shooter/dashboard/` - Three-step drill-down picker (Repos -> Files -> Shots)
- `lua/shooter/context/` - Context detection (telescope, oil, shotfile, buffer)
- `lua/shooter/tools/` - Clipboard image paste, Obsidian integration, response viewer, token counter
- `lua/shooter/health/` - Health check module
- `lua/shooter/filter_state.lua` - Global filter state management

## Data Flow

**Sending a Shot to an AI Agent:**

1. User triggers `:ShoShotSend {pane}` (or keymap `<leader>{1-4}`)
2. `commands.lua` dispatches to `tmux.send_current_shot(pane_index)`
3. `tmux/operations.lua` calls `tmux/create.find_or_create_ai_pane()` to resolve the target pane ID
4. Provider detection: `providers/init.lua` checks tmux pane variables first, then falls back to `ps aux` TTY matching
5. `tmux/messages.lua` builds the full message (shot content + optional context injection)
6. `tmux/send.lua` writes text to a temp file, then uses `tmux load-buffer` + `tmux paste-buffer -p` to send (or `send-keys` in keys mode)
7. `core/shots.lua` marks the shot header as executed with timestamp
8. A "bullet" file is saved to `~/.config/shooter/nvim/bullets/{repo}/` for analytics tracking

**Creating a New Shotfile:**

1. User triggers `:ShoShotfileNew` with optional title argument
2. If mono-repo with `projects/` folder: project picker shown first
3. `core/files.lua` creates the file from template at `{git_root}/.shooter/ai/shotfiles/{name}.md`
4. Buffer opens at line 4 in insert mode

**Telescope Picker Flow:**

1. Command dispatches to `telescope/pickers.lua` function
2. Session module provides current filter/sort state per repo
3. `core/files.lua` lists files, `core/shots.lua` finds shots within them
4. Telescope displays with custom previewers from `telescope/previewers.lua`
5. Custom actions (send, move, delete, etc.) from `telescope/actions.lua`

**State Management:**
- Plugin config: In-memory Lua table merged at `setup()` time, accessed via `config.get('dotted.path')` from `lua/shooter/config.lua`
- External config: YAML files at `~/.config/shooter/nvim/config.yaml` (global) and `{repo}/.shooter/cfg/nvim/config.yaml` (project-local), loaded with caching in `lua/shooter/core/ext_config.lua`
- Session state: JSON files at `~/.config/shooter/nvim/sessions/{repo_slug}/` managed by `lua/shooter/session/storage.lua`
- Queue state: JSON file at `{repo}/.shooter/ai/shotfiles/.shot-queue.json` managed by `lua/shooter/queue/storage.lua`
- Last shotfile tracking: Per-repo file at `~/.config/shooter/nvim/last-shotfile-{slug}` managed by `lua/shooter/core/files.lua`

## Key Abstractions

**Shot:**
- Purpose: The fundamental unit of work - a markdown section starting with `## shot N` (open) or `## x shot N` (executed)
- Examples: `lua/shooter/core/shots.lua`, `lua/shooter/core/shot_actions.lua`
- Pattern: Shots are detected by regex patterns defined in `config.lua` (`patterns.shot_header`, `patterns.open_shot_header`, `patterns.executed_shot_header`). A shot spans from its `##` header to the next `##` header or EOF.

**Shotfile:**
- Purpose: A markdown file containing one or more shots, living in `.shooter/ai/shotfiles/`
- Examples: `lua/shooter/core/files.lua`
- Pattern: Files are organized in subfolders (prompts, archive, backlog, done, reqs, wait, test) and can be moved between them

**Provider:**
- Purpose: Abstraction for an AI coding agent (Claude, OpenCode, Codex, Gemini, Copilot)
- Examples: `lua/shooter/providers/claude.lua`, `lua/shooter/providers/opencode.lua`
- Pattern: Each provider registers with `providers.register(name, provider_table)`. Provider tables expose `name`, `display_name`, `process_pattern`, `send_text()`, `send_file_reference()`, `build_shot_message()`, `get_create_command()`. Detection uses tmux pane variables (`@shooter_provider`) with `ps aux` fallback.

**Session:**
- Purpose: Named configuration state for telescope picker (which folders are visible, sort order, filters)
- Examples: `lua/shooter/session/init.lua`, `lua/shooter/session/storage.lua`
- Pattern: Sessions are per-repo, stored as JSON. An "init" session is created by default. Users can create/switch sessions.

## Entry Points

**Plugin Setup:**
- Location: `lua/shooter/init.lua`
- Triggers: User calls `require('shooter').setup({})` in their Neovim config
- Responsibilities: Merge config, register commands, register keymaps, setup syntax highlighting

**User Commands:**
- Location: `lua/shooter/commands.lua`
- Triggers: `:ShoXxx` commands or keymaps defined in `lua/shooter/keymaps.lua`
- Responsibilities: Dispatch to appropriate module functions; some commands are guarded by `require_shotfile()` which ensures the current buffer is in `.shooter/ai/shotfiles/`

**Syntax/Autocommands:**
- Location: `lua/shooter/syntax.lua`
- Triggers: `BufEnter` for shotfiles
- Responsibilities: Highlight shot headers, track last-edited shotfile

## Error Handling

**Strategy:** Defensive with user-facing notifications

**Patterns:**
- Guard functions: `require_shotfile(fn)` wraps commands to check context before execution
- `pcall` for external dependencies: config loading, template reading, YAML parsing
- `vim.notify()` for user-visible errors, `utils.echo()` for transient status messages
- Tmux commands use `2>/dev/null` and check return codes
- File operations return `(result, error_string)` tuples

## Cross-Cutting Concerns

**Logging:** No structured logging framework. Uses `vim.notify()` for user messages and `utils.echo()` for status bar messages. Tmux commands silently discard stderr.

**Validation:** Minimal explicit validation. Shot detection relies on pattern matching. File existence checked before operations. `is_shooter_file()` guard on most shot commands.

**Authentication:** Not applicable (plugin runs locally). AI provider authentication is handled by the providers' own CLI tools.

**Configuration:** Two-tier system:
1. Lua config (`config.lua`): Plugin internals, set at `setup()` time, accessed via `config.get('dotted.path')`
2. YAML config (`ext_config.lua`): User display preferences, layered (defaults < global YAML < project-local YAML), cached with explicit `reload()`

---

*Architecture analysis: 2026-04-03*
