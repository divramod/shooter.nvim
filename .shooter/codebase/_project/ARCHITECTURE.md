# Architecture

**Analysis Date:** 2026-02-08

## Pattern Overview

**Overall:** Modular plugin architecture with clear separation between command dispatch, core business logic, UI/integration layers, and persistence.

**Key Characteristics:**
- Command-driven entry point: all user interactions flow through a centralized command registry
- Telescope-based UI with stateful session management
- Tmux integration for AI collaboration workflows
- Context injection system for multi-file prompts
- Modular layer architecture with minimal cross-module dependencies

## Layers

**Command & Dispatch:**
- Purpose: Route all user commands to appropriate handlers, manage keymaps, translate user input into action
- Location: `lua/shooter/commands.lua`, `lua/shooter/keymaps.lua`, `lua/shooter/keymaps/`
- Contains: Vim command registration, keymap setup, command-to-handler mappings
- Depends on: Core modules for execution, config for settings
- Used by: Neovim (vim.api.nvim_create_user_command calls)

**Core Business Logic:**
- Purpose: Core shot/file/project management independent of UI
- Location: `lua/shooter/core/`
- Contains: Shot detection (`shots.lua`), file operations (`files.lua`), shot manipulation (`shot_actions.lua`), movement (`movement.lua`), templates (`templates.lua`), project detection (`project.lua`)
- Depends on: Utils, config
- Used by: Commands, Telescope, Tmux integration

**UI/Telescope Layer:**
- Purpose: Provide pickers and previews for file selection, shot selection, and interactive operations
- Location: `lua/shooter/telescope/`
- Contains: Picker implementation (`pickers.lua`), helpers (`helpers.lua`), actions (`actions.lua`), previewers (`previewers.lua`)
- Depends on: Core (files, shots), Session (state), Config
- Used by: Commands dispatch UI, user interaction

**Session & State Management:**
- Purpose: Persist and restore user preferences, folder filters, sort orders, and picker sessions
- Location: `lua/shooter/session/`
- Contains: Session lifecycle (`init.lua`), storage (`storage.lua`), filtering (`filter.lua`), sorting (`sort.lua`), picker UI (`picker.lua`)
- Depends on: Utils, files (for git root detection)
- Used by: Telescope layer, configuration commands

**Tmux Integration:**
- Purpose: Detect tmux environment, send shots to AI Claude pane, manage tmux session state
- Location: `lua/shooter/tmux/`
- Contains: Tmux detection (`detect.lua`), text sending (`send.lua`), message formatting (`messages.lua`), session creation (`create.lua`), pane operations (`panes.lua`), send operations (`operations.lua`)
- Depends on: Core (shots, files), config
- Used by: Commands (`ShoSend*`), key mappings

**Context Injection:**
- Purpose: Load and inject global/project context into prompts for AI consumption
- Location: `lua/shooter/context/`, `lua/shooter/core/context.lua`
- Contains: Context file resolution (`context/resolvers.lua`), context detection utilities
- Depends on: Core (files), config
- Used by: Tmux send operations

**Utilities & Infrastructure:**
- Purpose: Low-level utilities shared across all layers
- Location: `lua/shooter/utils.lua`, `lua/shooter/config.lua`, `lua/shooter/syntax.lua`
- Contains: File I/O, string manipulation, vim API wrappers, configuration defaults, syntax highlighting setup
- Depends on: None (leaf modules)
- Used by: All other modules

**Specialized Modules:**
- Analytics: `lua/shooter/analytics/` - Track shot creation/completion statistics
- Queue: `lua/shooter/queue/` - Store pending shots for later multi-pane execution
- Providers: `lua/shooter/providers/` - AI provider adapters (Claude, OpenCode)
- Tools: `lua/shooter/tools/` - Image handling, token counting, response viewing
- Dashboard: `lua/shooter/dashboard/` - Visual overview UI
- Inbox: `lua/shooter/inbox/` - Import tasks from external files

## Data Flow

**Shot Creation Flow:**

1. User invokes `ShoNewShot` → `commands.lua` dispatches to `shot_actions.create_new_shot()`
2. `shot_actions.lua` calls `shots.find_insertion_line()` to determine where to insert
3. `shot_actions.lua` calls `shots.get_next_shot_number()` to determine numbering
4. New shot header inserted into buffer with `utils.set_buf_lines()`
5. Cursor positioned for user input
6. On shot send: `shots.find_current_shot()` extracts shot boundaries
7. Context injected via `context/resolvers.lua`
8. Text sent to tmux via `tmux.send_current_shot()` → `send.lua` → `tmux send-keys`

**File Management Flow:**

1. User invokes `ShoCreate` → `commands.lua` dispatches
2. `files.create_file()` generates filename (timestamp + title)
3. File created at detected project or root level
4. File opened in vim buffer
5. Movement commands (`movement.lua`) move files between folders: archive, backlog, done, etc.
6. Movement uses `os.rename()` and Oil integration for visual feedback

**Session/Picker Flow:**

1. User invokes `ShoList` → `pickers.list_all_files()` in telescope module
2. `session.get_current_session()` loads filter state (which folders, sort order)
3. `files.get_prompt_files()` discovers all shots files
4. Finder builds entries, previewer generates preview for each
5. User actions (folder toggle, sort) update session state in-memory
6. Session saved with `session.save_current()` → `storage.write_session()`
7. On selection: dispatcher executes chosen action

**State Management Flow:**

1. Session state held in memory (`session._current_session`)
2. On any state change (folder toggle, sort, etc.): `session.save_current()` writes to disk
3. Session stored as JSON in `.shooter/session/config/<repo-slug>/<session-name>.json`
4. Next vim launch: `session.get_current_session()` loads last used session
5. Fallback to `init` session if no last session found

## Key Abstractions

**Shot:**
- Purpose: Represents a single numbered work item in a shotfile
- Examples: `lua/shooter/core/shots.lua` (detection), `lua/shooter/core/shot_actions.lua` (manipulation)
- Pattern: Header-based parsing (regex match on `## shot N` or `## x shot N`), boundary detection via line scanning

**Shotfile:**
- Purpose: Markdown file containing multiple shots and metadata
- Examples: `.shooter/shotfiles/archive/`, `.shooter/shotfiles/backlog/`, etc.
- Pattern: Title (# heading) → shots (## headings) → content

**Session:**
- Purpose: Persist user preferences (folder filters, sort order, vim mode) per repository
- Examples: `lua/shooter/session/init.lua`, `lua/shooter/session/storage.lua`
- Pattern: Repo-slug-based namespacing, JSON storage, in-memory cache with dirty tracking

**Context:**
- Purpose: Global + project-specific markdown that gets injected into every prompt
- Examples: `~/.config/shooter.nvim/shooter-context-global.md` (global), `.shooter/config/nvim/shooter-context-project.md` (per-project)
- Pattern: Template-based resolution via `context/resolvers.lua`

## Entry Points

**Plugin Initialization:**
- Location: `lua/shooter/init.lua`
- Triggers: User calls `require('shooter').setup(user_config)` in neovim config
- Responsibilities: Load config, register commands, set up keymaps, initialize syntax highlighting

**Command Dispatch:**
- Location: `lua/shooter/commands.lua`
- Triggers: User presses keymap or invokes Vim command
- Responsibilities: Route to appropriate handler based on command namespace (Shotfile, Shot, Tmux, Tool, etc.)

**Keymaps:**
- Location: `lua/shooter/keymaps.lua` + namespace handlers
- Triggers: User presses key combination
- Responsibilities: Dispatch to command or provide context-aware actions (Oil, Telescope)

**Telescope Pickers:**
- Location: `lua/shooter/telescope/pickers.lua`
- Triggers: Commands like `ShoList`, `ShoOpenShots`
- Responsibilities: Create Telescope picker with custom keymaps, refresh on filter change

## Error Handling

**Strategy:** Defensive but transparent—catch errors at layer boundaries, notify user, preserve state

**Patterns:**
- Vim.notify() for user-facing errors (with log level INFO/WARN/ERROR)
- Fallback to reasonable defaults (empty file list, init session, root project)
- Guard against missing tmux, git root, or configuration files
- pcall() for optional dependencies (oil.nvim, telescope)

**Example:**
```lua
-- From tmux/send.lua
local ok, result = pcall(M.execute_tmux_command, cmd)
if not ok then
  vim.notify('Tmux error: ' .. tostring(result), vim.log.levels.WARN)
  return
end
```

## Cross-Cutting Concerns

**Logging:** Console echo via `utils.echo()`, vim.notify() for user notifications. No persistent logs.

**Validation:** Regex-based pattern matching for shot headers. File existence checks before reads. Git root detection with fallback to cwd.

**Authentication:** N/A (plugin operates locally, AI auth handled by Claude CLI or similar)

**Configuration:** Centralized in `lua/shooter/config.lua` with defaults, user overrides via `setup()`. Config accessible via `config.get(key)` everywhere.

**File Paths:** All paths expanded via `utils.expand_path()` to handle `~` and env vars. Escape patterns for vim operations via `vim.pesc()`.

---

*Architecture analysis: 2026-02-08*
