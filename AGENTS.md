# AI Agent Configuration

Source: ~/a/ai v0.1.0 | Generated: 2026-01-30

> For OpenCode and Codex CLI. Claude Code uses CLAUDE.md, Gemini CLI uses GEMINI.md.

---

# shooter.nvim -- Project Context

## Project Overview

Neovim plugin for managing iterative development workflows using a shot-based approach. Shots are discrete work units defined in markdown shotfiles, which can be sent to AI agents via tmux panes. Refactored from divramod's dotfiles next-action workflow into a standalone, publishable plugin.

## Tech Stack

- **Language**: Lua (Neovim plugin)
- **Test Framework**: plenary.nvim (busted-style)
- **Dependencies**: telescope.nvim, oil.nvim, nui.nvim
- **External**: tmux, Claude Code CLI

## Repository Structure

```
lua/shooter/           Plugin source code
  core/                Core modules (files, shots, movement, project, context)
  telescope/           Telescope pickers and actions
  tmux/                Tmux integration (send, detect, create, panes)
  queue/               Shot queue management
  dashboard/           NuiTree dashboard UI
  session/             YAML session management
  keymaps/             Context-specific keymaps (picker, oil)
  context/             Context detection and resolvers
templates/             Context file templates
tests/                 plenary.nvim test specs
doc/                   Vim help documentation
plans/prompts/         Shotfiles (development tasks)
.shooter.nvim/         Per-repo config and images
```

## Development Workflow

- Work tracked in beads (`bd`), prefix: `snvim`
- Shots in `plans/prompts/*.md` define features and fixes
- `bd ready` to find work, `bd close` to complete
- Tests run via plenary: `:PlenaryBustedDirectory tests/`

## Key Conventions

- **200-line maximum per file**: Enforces single responsibility
- **Zero auto-initialization**: Plugin only activates when `setup()` is called
- **Context-aware commands**: Same keymap works identically across telescope, oil, and buffer contexts
- **8 namespaces**: Shotfile, Shot, Tmux, Subproject, Tools, Cfg, Analytics, Help

## Important Notes

- Always update README.md when adding commands, keybindings, or config options
- All modules have corresponding `*_spec.lua` test files
- Context files: global at `~/.config/shooter.nvim/`, project at `.shooter.nvim/`

---

## Codebase Overview

### STACK

# Technology Stack

**Analysis Date:** 2026-01-30

## Languages

**Primary:**
- Lua 5.1+ - Neovim plugin implementation
- Bash - System scripts for clipboard image handling and shell integration

**Secondary:**
- Markdown - Shot files, documentation, context templates

## Runtime

**Environment:**
- Neovim >= 0.9.0 (host runtime)
- Lua interpreter (bundled with Neovim)

**Package Manager:**
- None (plugin uses Lua standard library only)

## Frameworks

**Core UI & Integration:**
- `telescope.nvim` - Picker/selection UI for files, shots, queues, sessions
  - Used across modules: `lua/shooter/prd.lua`, `lua/shooter/inbox/picker.lua`, `lua/shooter/telescope/`
  - Provides fuzzy finding, previews, custom actions

- `nui.nvim` - Referenced in CLAUDE.md but minimal direct usage; appears to be optional dependency

- `oil.nvim` - File navigation and movement operations
  - Context-aware keymaps in `lua/shooter/keymaps/oil.lua`
  - Supports move commands across projects

**Editor Integration:**
- `vim-i3wm-tmux-navigator` - Seamless Neovim/tmux navigation (dependency in lazy.nvim config)

**Testing:**
- `plenary.nvim` - Testing framework (busted-style) for unit tests
  - Test runner: `:PlenaryBustedDirectory tests/`
  - Tests located in `tests/` directory with `*_spec.lua` naming convention
  - Example: `tests/core/shots_spec.lua` uses `describe()`, `it()`, `assert.` pattern

**Session Management:**
- YAML (custom serializer) for session persistence - `lua/shooter/session/storage.lua`
  - Custom parser/serializer (no external library)

## Key Dependencies

**Critical:**
- `telescope.nvim` - Core UX for all pickers and selection workflows
- `plenary.nvim` - Required for Telescope operation and testing
- `oil.nvim` - File movement and project navigation
- `vim-i3wm-tmux-navigator` - Pane/split navigation

**Optional but Integrated:**
- `gp.nvim` (optional) - Voice dictation with `<space>e` keybinding (`lua/shooter/keymaps.lua`)
- `nui.nvim` - Listed as dependency but not heavily used in codebase

## External Tools & CLI Integration

**AI Providers:**
- Claude Code CLI - Primary provider for sending shots
  - Detection in `lua/shooter/providers/claude.lua` (process pattern: `claude`)
  - Alternative: OpenCode CLI in `lua/shooter/providers/opencode.lua`

**Token Counting:**
- `ttok` CLI - Optional token counting in `lua/shooter/tools/token_counter.lua`
  - Installed via: `pip install ttok`
  - Used with command: `ttok < filename`

**Image Management:**
- `hal` CLI - Optional image picking for `<space>I` command (`lua/shooter/health/tools.lua`)
- Custom shell script: `scripts/shooter-clipboard-image` - Clipboard image saving
  - Saves images to `~/.clipboard-images` or `.shooter.nvim/images/`

**Knowledge Base Integration:**
- Obsidian vault detection and opening - `lua/shooter/tools/obsidian.lua`
  - Uses `obsidian://` URI scheme
  - Detects vault via `.obsidian` directory

**System Integration:**
- `tmux` - Required for sending shots to AI panes
  - Tmux operations: `lua/shooter/tmux/wrapper.lua`, `lua/shooter/tmux/operations.lua`
  - Commands: `send-keys`, `split-window`, `display-message`, `list-panes`
- `git` - Repository detection and information
  - Used for git root detection: `git rev-parse --show-toplevel`
  - Supports relative path resolution within repos

## Configuration

**Environment:**
- Plugin activation: Call `require('shooter').setup()` in config (zero auto-initialization)
- Config stored at: `lua/shooter/config.lua` - defaults override pattern
- User config merge via `setup()` function in `lua/shooter/init.lua`

**Key Config Paths:**
- Global context: `~/.config/shooter.nvim/shooter-context-global.md`
- Project context: `.shooter.nvim/shooter-context-project.md` (per-repo)
- Session storage: `~/.config/shooter.nvim/sessions/<owner>_<repo>/`
- Queue file: `plans/prompts/.shot-queue.json`
- Prompts directory: `plans/prompts/` (customizable)

**Feature Flags:**
- Located in `lua/shooter/config.lua` - `features` section
- Keymaps enabled/disabled per session
- Telescope layout strategy configurable

**Tmux Configuration:**
- Delay between send operations: 0.2s (configurable)
- Long message delay: 1.5s
- Send mode: `keys` (default, shows full text in history)
- Max panes: 9

## Platform Requirements

**Development:**
- Neovim >= 0.9.0
- Git (for repository detection)
- tmux (for sending to AI)
- macOS or Linux (platform detection for Obsidian opening)

**Optional Tooling:**
- `ttok` (Python) - Token counting
- `hal` CLI - Image picking
- Obsidian desktop app - For vault integration
- Claude Code CLI - For AI pane interaction
- `gp.nvim` - For voice dictation

**No Node/NPM Required:**
- Pure Lua/Neovim plugin
- All dependencies are Neovim plugins or system CLIs

## Build & Bundling

**Installation Methods:**
1. `lazy.nvim` - Primary plugin manager supported
2. `packer.nvim` - Also supported (config in README.md)
3. Manual installation - Clone to `~/.config/nvim/pack/`

**Entry Point:**
- `lua/shooter/init.lua` - Main module exported as `require('shooter').setup()`
- Plugin initialization via `:ShooterCreate`, `:ShooterList`, etc. commands
- Syntax highlighting setup in `lua/shooter/syntax.lua`

**No Compilation Needed:**
- Pure Lua, no C extensions
- No build step required

---

*Stack analysis: 2026-01-30*

### ARCHITECTURE

# Architecture

**Analysis Date:** 2026-01-30

## Pattern Overview

**Overall:** Plugin-based module architecture with context-aware command dispatch and provider abstraction.

**Key Characteristics:**
- Zero auto-initialization: Plugin only activates when `setup()` is called
- Context-aware operations: Same keymap produces different behavior based on active buffer context
- Multi-layered namespaces: 8 command namespaces (Shotfile, Shot, Tmux, Subproject, Tools, Cfg, Analytics, Help)
- Provider abstraction: Pluggable AI backend system (Claude Code, OpenCode)
- Session persistence: Per-repo configuration stored in YAML
- Event-driven UI updates: Telescope pickers with custom mappings and filters

## Layers

**Plugin Initialization:**
- Purpose: Entry point for setup, config merge, command registration
- Location: `lua/shooter/init.lua`
- Contains: `setup()` function, initialization guards, config management
- Depends on: config, commands, keymaps, syntax
- Used by: User init.lua config

**Command Layer:**
- Purpose: Dispatch user commands to namespace handlers
- Location: `lua/shooter/commands.lua`
- Contains: 50+ vim.nvim_create_user_command definitions across 8 namespaces
- Depends on: core modules (files, shots, movement, project), tmux, providers
- Used by: Keymaps, direct user invocation

**Core Business Logic:**
- Purpose: Core file/shot manipulation and metadata operations
- Location: `lua/shooter/core/` (14 modules)
- Contains: Shot detection, file CRUD, project detection, metadata parsing
- Key modules:
  - `shots.lua`: Find, mark, parse shots in buffers
  - `files.lua`: File path resolution, git root detection, prompts dir management
  - `shot_actions.lua`: Create/delete/toggle shots
  - `shot_move.lua`: Move shots between files
  - `shot_delete.lua`: Shot deletion with cleanup
  - `project.lua`: Mono-repo projects/ structure support
  - `context.lua`: File/buffer context detection
  - `movement.lua`: Navigate between shots
  - `rename.lua`: Rename/renumber shots
  - `templates.lua`: Template injection
  - `greenkeep.lua`: Auto-cleanup of executed shots
- Depends on: utils, config
- Used by: Commands, tmux operations, telescope pickers

**Tmux Integration Layer:**
- Purpose: Send shots to Claude/OpenCode in tmux panes
- Location: `lua/shooter/tmux/` (11 modules)
- Contains: TTY detection, pane management, text transmission, escape sequences
- Key modules:
  - `send.lua`: Escape sequences, delay calculation for large messages
  - `detect.lua`: Find Claude/OpenCode processes, match to panes
  - `operations.lua`: Orchestrate shot sending with multi-shot batching
  - `create.lua`: Create new tmux sessions/panes
  - `messages.lua`: Format messages with context injection
  - `panes.lua`: Query tmux panes and sessions
- Depends on: core (shots, files), config, providers
- Used by: Commands, telescope actions

**Telescope Integration Layer:**
- Purpose: Browse and select shots/files with custom actions
- Location: `lua/shooter/telescope/` (5 modules)
- Contains: Custom pickers, previewers, keymaps, actions
- Key modules:
  - `pickers.lua`: 7+ pickers (list_all_files, shot picker, dashboard, etc.)
  - `actions.lua`: Multi-select, send, delete, copy shots
  - `helpers.lua`: Selection state, filter application
  - `previewers.lua`: Inline preview of shot content
  - `picker_help.lua`: Help text for keymaps
- Depends on: core (shots, files, project), session, context
- Used by: Commands, keymaps

**Session Management Layer:**
- Purpose: Persist UI state across sessions (vim mode, filters, sorting)
- Location: `lua/shooter/session/` (8 modules)
- Contains: YAML storage, session state, filter/sort logic
- Key modules:
  - `storage.lua`: YAML I/O to ~/.config/shooter.nvim/sessions/<repo>/
  - `init.lua`: In-memory session lifecycle
  - `filter.lua`: Apply folder/project filters
  - `sort.lua`: Sort shots by status/priority/date
  - `defaults.lua`: Session schema
  - `picker.lua`: Telescope picker for session switching
- Depends on: utils, core
- Used by: Telescope pickers, commands

**Queue System:**
- Purpose: Manage shot queue for batch operations
- Location: `lua/shooter/queue/` (3 modules)
- Contains: Queue CRUD, storage to .shot-queue.json
- Key modules:
  - `storage.lua`: JSON persistence
  - `init.lua`: Queue API (add, remove, clear)
- Depends on: utils, config
- Used by: Commands, telescope actions

**Dashboard (Drill-Down Picker):**
- Purpose: Three-step navigation: Repos → Files → Shots
- Location: `lua/shooter/dashboard/` (2 modules)
- Contains: Multi-picker choreography with back-navigation
- Key modules:
  - `data.lua`: Fetch repos, files, open shots
  - `init.lua`: Picker UI with navigation flow
- Depends on: telescope, core (files, project)
- Used by: Commands

**Keymaps Layer:**
- Purpose: Organize and register default keybindings
- Location: `lua/shooter/keymaps.lua` + `lua/shooter/keymaps/` (3 sub-modules)
- Contains: 50+ keymaps organized by namespace (f, s, t, m, c prefixes)
- Key modules:
  - `keymaps.lua`: Main keymap registration with context-aware dispatch
  - `picker.lua`: Context-specific picker keymaps (folder toggles, session ops)
  - `oil.lua`: Oil file manager buffer keymaps
- Depends on: config, commands, context/resolvers
- Used by: init.lua setup

**Context Resolution Layer:**
- Purpose: Detect current context and resolve command targets
- Location: `lua/shooter/context/` (2 modules)
- Contains: Context detection (telescope, oil, shotfile), target resolution
- Key modules:
  - `init.lua`: Detect buffer type (picker, oil, shotfile, normal)
  - `resolvers.lua`: Resolve shot/shotfile targets from context
- Depends on: core (shots, files)
- Used by: Commands, keymaps

**Provider Abstraction:**
- Purpose: Pluggable AI backend system for multi-provider support
- Location: `lua/shooter/providers/` (3 modules)
- Contains: Provider registry, detection logic, backend implementations
- Key modules:
  - `init.lua`: Provider registry and process detection
  - `claude.lua`: Claude Code configuration
  - `opencode.lua`: OpenCode configuration
- Depends on: utils
- Used by: Tmux operations, commands

**Analytics & Observability:**
- Purpose: Track shot execution, generate usage reports
- Location: `lua/shooter/analytics/` (4 modules)
- Contains: Analytics data collection, chart generation, reports
- Key modules:
  - `data.lua`: Load and compute shot statistics
  - `chart.lua`: ASCII chart rendering
  - `report.lua`: Generate usage reports
- Depends on: core (shots, files)
- Used by: Commands

**Utilities:**
- Purpose: Shared helper functions
- Location: `lua/shooter/utils.lua`, `lua/shooter/help.lua`, `lua/shooter/sound.lua`
- Contains: File I/O, buffer operations, messaging, sound playback
- Depends on: (none)
- Used by: All layers

## Data Flow

**Opening and Sending a Shot:**

1. User in shotfile buffer → presses `<space>1` (send to pane 1)
2. Keymap triggers `ShooterShotSend1` command
3. Command resolves context via `context.resolvers.resolve_shot_target()`
4. Returns target with header_line, start_line, end_line, bufnr
5. `tmux.send.send_current_shot(1)` retrieves shot lines from buffer
6. `tmux.detect.find_pane_for_index(1)` finds tmux pane ID via TTY matching
7. `tmux.send.prepare_escape_sequences()` clears pane state (C-c, C-u)
8. Text sent via tmux send-keys with delay based on message size
9. `shot_actions.mark_shot_executed()` adds timestamp and x marker to header
10. Sound plays if enabled in config

**Telescope Shot Picker Flow:**

1. User opens picker via `ShooterShotPicker` command
2. `telescope.pickers.list_all_files()` creates picker with telescope.finders.new_table
3. `telescope.helpers.build_entries()` scans shotfiles, parses shots, builds results
4. Picker applies session filters (folders, projects) via `session.filter.apply()`
5. Picker applies session sorting (status, priority, date) via `session.sort.apply()`
6. User selects shot (insert mode) or uses keymaps (normal mode):
   - `<space>1-4`: Send to panes 1-4
   - `a`: Add to queue
   - `d`: Delete shot
   - `y`: Yank shot
7. Multi-select via `helpers.toggle_selection()` (tracked in memory)
8. Selected shots sent via `tmux.send_specific_shots()`
9. User saves session manually (ss keymap) → `session.storage.write_session()`

**Session Load/Save:**

1. Picker opens → `session.init.get_current_session()` loads last used session
2. Session YAML read from `~/.config/shooter.nvim/sessions/<repo>/`
3. Session contains: name, filters (folders, projects), sort order, vim mode
4. Filters applied to picker → only matching shots shown
5. User changes filters via folder keymaps (1-6, a-z)
6. `session.init.toggle_folder()` updates in-memory session state
7. User presses `ss` → `session.storage.write_session()` persists to YAML
8. Session metadata file tracks last-loaded session per repo

**Context-Aware Command Dispatch:**

1. Same keymap `<space>.` works in 3 contexts:
   - In shotfile buffer: Toggle current shot's x marker (mark as executed)
   - In telescope picker: Toggle selected shot
   - In Oil buffer: Not applicable (no-op)
2. `context.resolvers.resolve_shot_target()` detects context:
   - Check if current buffer is telescope picker
   - Check if current buffer is oil buffer
   - Check if current buffer is shotfile
3. Returns appropriate target with bufnr + line info or nil
4. Command handler uses target to apply operation

**State Management:**

- **In-memory per-session:** Session filters, sort order, multi-select state (kept in helpers.lua)
- **In-memory per-repo:** Current session name, repo slug (kept in session.init.lua)
- **Persistent per-repo:** Session YAML files in ~/.config/shooter.nvim/sessions/<repo>/
- **Per-file:** Shot execution timestamps, x markers (in markdown files)
- **Global:** Context files (.shooter.nvim/shooter-context-project.md, ~/.config/shooter.nvim/shooter-context-global.md)

## Key Abstractions

**Shot:**
- Purpose: Represents a discrete work unit with number, title, content
- Examples: `lua/shooter/core/shots.lua`
- Pattern: Shot parsed from markdown (## shot N), boundaries detected by headers and code blocks
- Structure: header_line, start_line, end_line (buffer positions), execution timestamp

**Shotfile:**
- Purpose: Markdown file containing multiple shots
- Examples: `plans/prompts/*.md`
- Pattern: One file per feature/task, title (# ...) at top, shots (## shot N) below
- Naming: title-slug.md (auto-generated from title, can be renamed)

**File Context:**
- Purpose: Abstraction for working with files in different situations
- Examples: normal buffer, Oil directory browser, shotfile picker
- Pattern: `context/init.lua` detects context, `context/resolvers.lua` resolves targets
- Enables: Same command works identically across all contexts

**Provider:**
- Purpose: Abstraction for different AI backends
- Examples: `providers/claude.lua`, `providers/opencode.lua`
- Pattern: Registry pattern with process_pattern for TTY detection
- Enables: Easy addition of new AI backends without changing core logic

**Session:**
- Purpose: Per-repo UI state that persists across Vim sessions
- Examples: Filter settings, sort order, vim mode (insert/normal in pickers)
- Pattern: YAML files in ~/.config/shooter.nvim/sessions/<repo>/
- Structure: name, filters (projects, folders), sort order, layout

**Queue:**
- Purpose: Ordered list of shots to be sent
- Examples: `.shot-queue.json`
- Pattern: Add shots to queue, send in order, clear when done
- Structure: Array of {file, shot_number, title}

## Entry Points

**Plugin Entry:**
- Location: `lua/shooter/init.lua`
- Triggers: User calls `require('shooter').setup(config)` in init.lua
- Responsibilities: Initialize config, register commands, set up keymaps, enable syntax highlighting

**Command Entry:**
- Location: `lua/shooter/commands.lua`
- Triggers: User runs any `:Shooter*` command
- Responsibilities: Route to appropriate handler (core, tmux, session, etc.)

**Keymap Entry:**
- Location: `lua/shooter/keymaps.lua`
- Triggers: User presses mapped key (e.g., `<space>1`)
- Responsibilities: Lookup command, resolve target context, execute

**Telescope Picker Entry:**
- Location: `lua/shooter/telescope/pickers.lua`
- Triggers: Commands that open pickers (list_all_files, shot picker, dashboard)
- Responsibilities: Fetch data, build entries, apply filters/sorts, set up keymaps

**Context Detection Entry:**
- Location: `lua/shooter/context/init.lua` + `resolvers.lua`
- Triggers: Any command that needs to know current context
- Responsibilities: Detect buffer type, resolve target from context

## Error Handling

**Strategy:** Fail fast with clear error messages; validate at boundaries only.

**Patterns:**
- **File operations:** Check existence before read, report path in error message
- **Tmux operations:** Check pane existence, validate TTY, graceful fallback if process not found
- **Buffer operations:** Check buffer validity before accessing lines
- **Telescope:** Return nil if no entry selected (picker closes gracefully)
- **Config:** Deep merge with defaults, return sensible defaults if key missing

**Examples:**
- `files.lua`: `if vim.v.shell_error ~= 0` after git commands
- `send.lua`: `if not handle` after popen, falls back to paste mode
- `shots.lua`: Return nil if shot not found (no exception, just nil)
- `context/init.lua`: Return nil if context unrecognized

## Cross-Cutting Concerns

**Logging:** No dedicated logger; uses `vim.notify()` for user-facing messages, `utils.echo()` for command output

**Validation:**
- Path validation: Check file/dir exists before operations
- Shot validation: Verify shot headers match pattern, skip headers in code blocks
- Tmux validation: Verify pane exists before send, check TTY mapping

**Authentication:**
- Not applicable (local plugin, no external auth required)
- Assumes tmux session already running with Claude/OpenCode process

**File I/O:**
- Read: `utils.read_file()` with error return
- Write: `utils.write_file()` with error return
- Create: `utils.ensure_dir()` with 'p' flag
- No atomic operations, relies on filesystem atomicity

**UI Feedback:**
- `vim.notify()` for user actions (sent, deleted, etc.)
- `utils.echo()` for status messages (no vim prompt)
- Telescope previewer for inline content display
- Sound notification on shot sent (if enabled)

---

*Architecture analysis: 2026-01-30*

### STRUCTURE

# Codebase Structure

**Analysis Date:** 2026-01-30

## Directory Layout

```
shooter.nvim/
├── lua/shooter/                    # Main plugin source (71 Lua files)
│   ├── init.lua                    # Plugin entry point: setup() function
│   ├── config.lua                  # Configuration defaults and merge logic
│   ├── commands.lua                # 50+ vim command registrations
│   ├── keymaps.lua                 # Default keymap setup and dispatch
│   ├── utils.lua                   # Shared utilities (file I/O, buffer ops)
│   ├── help.lua                    # Help text and cheatsheet
│   ├── syntax.lua                  # Vim syntax highlighting rules for prompts
│   ├── cheatsheet.lua              # Keymap cheatsheet
│   ├── prd.lua                     # PRD (Product Requirements Doc) integration
│   ├── sound.lua                   # Sound notification playback
│   ├── images.lua                  # Image handling utilities
│   ├── filter_state.lua            # Filter state management for pickers
│   │
│   ├── core/                       # Core business logic (14 modules)
│   │   ├── shots.lua               # Shot detection and parsing (80 lines)
│   │   ├── files.lua               # File path resolution (150+ lines)
│   │   ├── shot_actions.lua        # Create/delete/mark shots (280+ lines)
│   │   ├── shot_delete.lua         # Shot deletion with cleanup (50 lines)
│   │   ├── shot_move.lua           # Move shots between files (150+ lines)
│   │   ├── movement.lua            # Navigate between shots (180+ lines)
│   │   ├── project.lua             # Mono-repo projects/ support (120+ lines)
│   │   ├── context.lua             # File/buffer context detection (100+ lines)
│   │   ├── rename.lua              # Rename/renumber shots (120+ lines)
│   │   ├── renumber.lua            # Auto-renumber shots (180+ lines)
│   │   ├── templates.lua           # Template injection and creation (200+ lines)
│   │   ├── greenkeep.lua           # Auto-cleanup of executed shots (120+ lines)
│   │   └── repos.lua               # Multi-repo handling (100 lines)
│   │
│   ├── tmux/                       # Tmux integration (11 modules)
│   │   ├── init.lua                # Tmux API entry point (87 lines)
│   │   ├── send.lua                # Escape sequences and delay calc (190 lines)
│   │   ├── detect.lua              # Find Claude/OpenCode panes (164 lines)
│   │   ├── operations.lua          # Orchestrate shot sending (191 lines)
│   │   ├── messages.lua            # Format messages with context (142 lines)
│   │   ├── create.lua              # Create tmux sessions/panes (196 lines)
│   │   ├── panes.lua               # Query tmux panes and sessions (161 lines)
│   │   ├── keys.lua                # Tmux key escape sequences (61 lines)
│   │   ├── shell.lua               # Shell command execution (85 lines)
│   │   ├── watch.lua               # Watch tmux for new panes (81 lines)
│   │   └── wrapper.lua             # Wrapper for tmux commands (140 lines)
│   │
│   ├── telescope/                  # Telescope UI integration (5 modules)
│   │   ├── pickers.lua             # 7+ pickers (437 lines)
│   │   ├── actions.lua             # Custom picker actions (140 lines)
│   │   ├── helpers.lua             # Selection state, filtering (369 lines)
│   │   ├── previewers.lua          # Inline shot preview (140 lines)
│   │   └── picker_help.lua         # Help text for pickers (153 lines)
│   │
│   ├── session/                    # Session state management (8 modules)
│   │   ├── init.lua                # Session lifecycle and caching
│   │   ├── storage.lua             # YAML I/O to ~/.config/shooter.nvim/
│   │   ├── defaults.lua            # Session schema
│   │   ├── filter.lua              # Apply folder/project filters
│   │   ├── sort.lua                # Sort shots by status/priority/date
│   │   ├── picker.lua              # Session selection picker
│   │   └── migrations.lua          # Schema migrations
│   │
│   ├── queue/                      # Shot queue management (3 modules)
│   │   ├── init.lua                # Queue API (add, remove, clear, view)
│   │   └── storage.lua             # JSON persistence to .shot-queue.json
│   │
│   ├── dashboard/                  # Drill-down picker UI (2 modules)
│   │   ├── init.lua                # Three-step picker flow
│   │   └── data.lua                # Fetch repos, files, shots
│   │
│   ├── keymaps/                    # Context-specific keymaps (3 modules)
│   │   ├── picker.lua              # Keymaps for telescope picker
│   │   └── oil.lua                 # Keymaps for oil file manager
│   │
│   ├── context/                    # Context resolution (2 modules)
│   │   ├── init.lua                # Detect buffer type (telescope, oil, etc.)
│   │   └── resolvers.lua           # Resolve shot/shotfile targets
│   │
│   ├── providers/                  # AI backend abstraction (3 modules)
│   │   ├── init.lua                # Provider registry and detection
│   │   ├── claude.lua              # Claude Code backend
│   │   └── opencode.lua            # OpenCode backend
│   │
│   ├── analytics/                  # Usage analytics (4 modules)
│   │   ├── data.lua                # Analytics data computation
│   │   ├── init.lua                # Analytics API
│   │   ├── chart.lua               # ASCII chart rendering
│   │   └── report.lua              # Report generation
│   │
│   ├── health/                     # Plugin health check (2 modules)
│   │   └── init.lua                # Health check logic
│   │
│   ├── inbox/                      # Inbox/task import (2 modules)
│   │   └── init.lua                # Import tasks from markdown
│   │
│   ├── tools/                      # Utility tools (3 modules)
│   │   ├── token_counter.lua       # Count tokens in text
│   │   ├── clipboard_image.lua     # Handle clipboard images
│   │   └── obsidian.lua            # Obsidian integration
│   │
├── plugin/                         # Neovim plugin initialization
│   └── (not checked in, plugin/ dir is usually auto-created)
│
├── templates/                      # Context file templates
│   ├── shooter-context-global-template.md     # Global context template
│   ├── shooter-context-project-template.md    # Project context template
│   └── shooter-context-message.md             # Message template
│
├── doc/                            # Vim help documentation
│   └── shooter.txt                 # Generated help file (230+ lines)
│
├── tests/                          # Test suite (plenary.nvim/busted)
│   ├── minimal_init.lua            # Test environment setup
│   ├── core/                       # Core logic tests (13 test files)
│   │   ├── shots_spec.lua
│   │   ├── files_spec.lua
│   │   ├── shot_actions_spec.lua
│   │   ├── shot_delete_spec.lua
│   │   ├── movement_spec.lua
│   │   ├── rename_spec.lua
│   │   ├── renumber_spec.lua
│   │   ├── project_spec.lua
│   │   ├── greenkeep_spec.lua
│   │   ├── templates_spec.lua
│   │   ├── analytics_spec.lua
│   │   ├── sound_spec.lua
│   │   └── context_spec.lua
│   │
│   ├── tmux/                       # Tmux tests (4 test files)
│   │   ├── init_spec.lua
│   │   ├── send_spec.lua
│   │   ├── detect_spec.lua
│   │   ├── create_spec.lua
│   │   └── panes_spec.lua
│   │
│   ├── telescope/                  # Telescope tests (2 test files)
│   │   └── (test files for pickers)
│   │
│   ├── session/                    # Session tests (4 test files)
│   │   ├── storage_spec.lua
│   │   ├── filter_spec.lua
│   │   ├── sort_spec.lua
│   │   └── defaults_spec.lua
│   │
│   ├── queue/                      # Queue tests
│   │   └── (test files)
│   │
│   ├── providers/                  # Provider tests
│   │   └── init_spec.lua
│   │
│   ├── dashboard/                  # Dashboard tests
│   │   └── data_spec.lua
│   │
│   ├── tools/                      # Tool tests
│   │   ├── token_counter_spec.lua
│   │   ├── clipboard_image_spec.lua
│   │   └── obsidian_spec.lua
│   │
│   └── filter_state_spec.lua       # Filter state tests
│
├── plans/prompts/                  # Development tasks (shot files)
│   └── *.md                        # One shotfile per feature
│
├── after/syntax/                   # Neovim after/syntax directory
│   └── (syntax file overrides)
│
├── scripts/                        # Build and utility scripts
│   └── (maintenance scripts)
│
├── .shooter.nvim/                  # Per-repo configuration
│   ├── shooter-context-project.md  # Project-specific context file
│   └── (project images, settings)
│
├── CLAUDE.md                       # AI agent configuration
├── README.md                       # Plugin documentation
├── AGENTS.md                       # Multi-agent workflow doc
└── LICENSE                         # MIT license
```

## Directory Purposes

**`lua/shooter/`:**
- Purpose: Main plugin source code
- Contains: 71 Lua files, ~12,600 lines total
- Key files: init.lua (entry), commands.lua (command dispatch), config.lua (configuration)

**`lua/shooter/core/`:**
- Purpose: Core file and shot manipulation logic
- Contains: 14 modules for shot detection, parsing, creation, deletion, movement
- Key files: shots.lua (parsing), files.lua (path resolution), shot_actions.lua (CRUD)
- Pattern: Single responsibility per module, under 200 lines each

**`lua/shooter/tmux/`:**
- Purpose: Integrate with tmux to send shots to Claude/OpenCode
- Contains: 11 modules for pane detection, text transmission, session management
- Key files: send.lua (transmission), detect.lua (process detection), operations.lua (orchestration)
- Pattern: High-level operations orchestrated from operations.lua, low-level in submodules

**`lua/shooter/telescope/`:**
- Purpose: Custom Telescope pickers and UI interactions
- Contains: 5 modules for picker UI, custom actions, filtering, sorting
- Key files: pickers.lua (picker definitions), helpers.lua (state and filtering), actions.lua (keymaps)
- Pattern: One picker per major workflow, shared state in helpers.lua

**`lua/shooter/session/`:**
- Purpose: Persist UI state (filters, sorting) across Vim sessions per repo
- Contains: 8 modules for YAML storage, filter/sort logic, session lifecycle
- Key files: storage.lua (I/O), init.lua (in-memory state), filter.lua and sort.lua (operations)
- Pattern: YAML storage in ~/.config/shooter.nvim/sessions/<repo-slug>/

**`lua/shooter/queue/`:**
- Purpose: Manage ordered queue of shots to be sent
- Contains: 3 modules for queue operations and JSON persistence
- Key files: init.lua (API), storage.lua (JSON I/O)
- Pattern: Simple append-only queue in .shot-queue.json

**`lua/shooter/dashboard/`:**
- Purpose: Three-step drill-down picker (Repos → Files → Shots)
- Contains: 2 modules for picker flow and data fetching
- Key files: init.lua (picker UI), data.lua (fetch and compute)
- Pattern: Telescope picker chain with back-navigation

**`lua/shooter/keymaps/`:**
- Purpose: Context-specific keybindings for picker and oil buffers
- Contains: 3 modules for keymap registration
- Key files: picker.lua (picker-specific keys), oil.lua (oil-specific keys)
- Pattern: Registered by main keymaps.lua setup, context-aware dispatch

**`lua/shooter/context/`:**
- Purpose: Detect current buffer context and resolve command targets
- Contains: 2 modules for context detection and target resolution
- Key files: init.lua (detection logic), resolvers.lua (target resolution)
- Pattern: Central point for context-aware command dispatch

**`lua/shooter/providers/`:**
- Purpose: Pluggable abstraction for different AI backends
- Contains: 3 modules for provider registry and implementations
- Key files: init.lua (registry), claude.lua and opencode.lua (backends)
- Pattern: Registry pattern with process_pattern for TTY detection

**`lua/shooter/analytics/`:**
- Purpose: Track shot execution and generate usage reports
- Contains: 4 modules for data collection, charts, and reports
- Key files: data.lua (statistics), report.lua (formatting)
- Pattern: Analytics computed from shotfile metadata (x markers, timestamps)

**`lua/shooter/health/`:**
- Purpose: Plugin health check (:checkhealth)
- Contains: 2 modules for validation logic
- Key files: init.lua (health checks)
- Pattern: Checks tmux, Claude/OpenCode, git, dependencies

**`lua/shooter/inbox/`:**
- Purpose: Import tasks from markdown inbox files
- Contains: 2 modules for task parsing and import
- Key files: init.lua (import logic)
- Pattern: Parse markdown task format, create shotfiles

**`lua/shooter/tools/`:**
- Purpose: Utility tools (token counting, image handling, integrations)
- Contains: 3 modules for tools
- Key files: token_counter.lua (OpenAI API), clipboard_image.lua (paste), obsidian.lua (note sync)
- Pattern: Optional tools, loaded on-demand

**`templates/`:**
- Purpose: Context file templates
- Contains: 3 markdown templates for context injection
- Key files: shooter-context-project-template.md, shooter-context-message.md
- Pattern: User-editable templates, copied to project/.shooter.nvim/ on first use

**`tests/`:**
- Purpose: Comprehensive test suite using plenary.nvim (busted-style)
- Contains: 30+ test specs mirroring source structure
- Key files: *_spec.lua for each major module
- Pattern: Run with `:PlenaryBustedDirectory tests/`

**`doc/`:**
- Purpose: Vim help documentation
- Contains: Automatically generated help file
- Key files: shooter.txt (230+ lines)
- Pattern: Generated from README and commands, viewable in `:help shooter`

**`plans/prompts/`:**
- Purpose: Development tasks tracked as shots
- Contains: Markdown shotfiles for features, fixes, refactoring
- Key files: *.md files, one per task
- Pattern: Beads workflow, prefix snvim-*

## Key File Locations

**Entry Points:**
- `lua/shooter/init.lua`: Plugin setup function
- `lua/shooter/commands.lua`: Command registration (50+)
- `lua/shooter/keymaps.lua`: Default keymap setup

**Configuration:**
- `lua/shooter/config.lua`: Defaults and merge logic
- `.shooter.nvim/shooter-context-project.md`: Per-project context
- `~/.config/shooter.nvim/shooter-context-global.md`: Global context (after first use)
- `~/.config/shooter.nvim/sessions/<repo>/`: Per-repo UI state (YAML)

**Core Logic:**
- `lua/shooter/core/shots.lua`: Shot detection and parsing
- `lua/shooter/core/files.lua`: File operations and path resolution
- `lua/shooter/core/shot_actions.lua`: Create/delete/mark shots
- `lua/shooter/core/project.lua`: Project (mono-repo) support

**Tmux Integration:**
- `lua/shooter/tmux/send.lua`: Send text to tmux panes
- `lua/shooter/tmux/detect.lua`: Find Claude/OpenCode panes by TTY
- `lua/shooter/tmux/operations.lua`: Orchestrate shot sending

**UI and Pickers:**
- `lua/shooter/telescope/pickers.lua`: Telescope picker definitions
- `lua/shooter/telescope/helpers.lua`: Selection state and filtering
- `lua/shooter/dashboard/init.lua`: Drill-down picker flow
- `lua/shooter/session/picker.lua`: Session selection

**Session Management:**
- `lua/shooter/session/init.lua`: Session lifecycle (get, update, save)
- `lua/shooter/session/storage.lua`: YAML I/O
- `lua/shooter/session/filter.lua`: Folder/project filtering
- `lua/shooter/session/sort.lua`: Shot sorting

**Context Resolution:**
- `lua/shooter/context/init.lua`: Detect buffer context
- `lua/shooter/context/resolvers.lua`: Resolve command targets from context

## Naming Conventions

**Files:**
- Lua files: `snake_case.lua` (e.g., `shot_actions.lua`, `send.lua`)
- Test files: `{module}_spec.lua` (e.g., `shots_spec.lua`)
- Markdown files: `kebab-case.md` (e.g., `shooter-context-project.md`)

**Directories:**
- Module directories: `lowercase` (e.g., `core`, `tmux`, `telescope`)
- No abbreviations (prefer full names for clarity)

**Functions:**
- Public API: `CamelCase()` for vim commands (e.g., `ShooterShotSend1`)
- Internal: `snake_case()` (e.g., `find_current_shot()`)
- Booleans: `is_*`, `has_*`, `should_*` (e.g., `is_in_code_block()`)

**Variables:**
- Local: `snake_case` (e.g., `shot_start`, `header_line`)
- Constants: `UPPER_SNAKE_CASE` in config defaults
- Module tables: `M` (convention for module export)

**Patterns in Filenames:**
- `*_spec.lua`: Test file for module
- `init.lua`: Module namespace entry point (e.g., `tmux/init.lua`, `queue/init.lua`)
- `*_template.md`: Context file template
- `*_context*.md`: Context file (global or project-specific)

## Where to Add New Code

**New Feature (e.g., new shot action):**
- Primary code: `lua/shooter/core/shot_actions.lua` or new module in `core/`
- Command registration: Add to `lua/shooter/commands.lua` (Shotfile, Shot, Tmux, etc. namespace)
- Keymap: Add to `lua/shooter/keymaps.lua` (f, s, t, m, c prefix)
- Test: `tests/core/{feature}_spec.lua`

**New Telescope Picker:**
- Implementation: Add function to `lua/shooter/telescope/pickers.lua`
- Custom actions: Register in `lua/shooter/telescope/actions.lua`
- Keymaps: Add context-specific keys in `lua/shooter/keymaps/picker.lua`
- Test: `tests/telescope/{picker}_spec.lua`

**New Tmux Capability:**
- Core logic: `lua/shooter/tmux/{capability}.lua` (new module if large)
- Public API: Export from `lua/shooter/tmux/init.lua`
- Operations: Call from `lua/shooter/tmux/operations.lua`
- Test: `tests/tmux/{capability}_spec.lua`

**New Utility Function:**
- General utilities: `lua/shooter/utils.lua` (max 250 lines, else split)
- Context-specific: Create submodule in appropriate directory
- Tool utilities: `lua/shooter/tools/{tool_name}.lua`
- Test: `tests/{location}_spec.lua`

**Configuration Option:**
- Add to defaults table in `lua/shooter/config.lua`
- Document in README.md and CLAUDE.md
- Reference as `config.get('section.key')` throughout code
- Use `config.set()` for runtime modifications

**New Command:**
- Add vim command in `lua/shooter/commands.lua`
- Assign to namespace (Shotfile, Shot, Tmux, Subproject, Tool, Cfg, Analytics, Help)
- Create corresponding keymap in `lua/shooter/keymaps.lua` if appropriate
- Update README.md Commands section

## Special Directories

**`lua/shooter/core/`:**
- Purpose: Core business logic for shot/file management
- Generated: No
- Committed: Yes
- Max file size: 200 lines (split if larger)
- Pattern: Single responsibility per module

**`~/.config/shooter.nvim/`:**
- Purpose: User configuration and session storage
- Generated: Yes (created on first use)
- Committed: No (user-specific)
- Contents: Global context file, sessions/ directory (YAML files)

**`.shooter.nvim/`:**
- Purpose: Per-project configuration
- Generated: No (user creates manually)
- Committed: Yes (part of repo)
- Contents: `shooter-context-project.md` (project-specific context), images, settings

**`plans/prompts/`:**
- Purpose: Development tasks (shots)
- Generated: Yes (created via `ShooterShotfileNew` command)
- Committed: Yes (part of repo)
- Pattern: One markdown file per task/feature

**`tests/`:**
- Purpose: Test suite
- Generated: No
- Committed: Yes
- Pattern: Structure mirrors `lua/shooter/`, one *_spec.lua per module

---

*Structure analysis: 2026-01-30*

### CONVENTIONS

# Coding Conventions

**Analysis Date:** 2026-01-30

## Naming Patterns

**Files:**
- Snake_case with underscores: `shot_delete.lua`, `clipboard_image.lua`, `token_counter.lua`
- Directories use snake_case: `core/`, `tmux/`, `telescope/`, `context/`, `session/`
- Test files append `_spec.lua`: `shots_spec.lua`, `project_spec.lua`, `shell_spec.lua`

**Functions:**
- Snake_case for all function names: `find_current_shot()`, `mark_shot_executed()`, `get_git_root()`
- Private helper functions prefixed with underscore: `local function is_in_code_block()`, `local function get_day_start()`
- Exported functions (in module M) follow snake_case without prefix: `M.find_all_shots()`, `M.get_shot_content()`

**Variables:**
- Snake_case: `shot_start`, `shot_end`, `header_line`, `current_title`, `new_filename`
- Descriptive names describing what is held: `bufnr` (buffer number), `filepath` (full path), `shot_info` (shot information table)
- Loop counters: `i`, `j` for numeric loops; `_, value` when unpacking tables

**Types/Tables:**
- Tables returned with descriptive field names: `{ start_line = X, end_line = Y, header_line = Z, is_executed = bool }`
- Config table keys use dot notation in string keys: `config.get('patterns.shot_header')`, `config.get('paths.prompts_root')`
- Namespaced constants via table structure: `M.persistent_state`, `M._initialized`, `M._config`

## Code Style

**Formatting:**
- Lua standard indentation (no configuration file enforced; uses standard 2-space indentation)
- Lines can exceed typical limits (seen up to 100+ characters)
- Function documentation in comments above function definition
- Comments are concise and describe the "why"

**Module Structure:**
- Every module starts with `local M = {}` to define exports
- Module ends with `return M` to export the public API
- Private functions defined with `local function` prefix
- Public functions attached to M: `function M.my_function() end`

**Patterns:**
- Guards at function start: `if not condition then return end`
- Use of default parameters: `bufnr = bufnr or 0`, `level = level or vim.log.levels.INFO`
- Safe require with pcall for optional dependencies: `local ok, oil = pcall(require, 'oil')` followed by `if ok then ... end`

## Import Organization

**Order:**
1. Comment header describing module purpose
2. Local module imports (require calls)
3. Module initialization (`local M = {}`)
4. Helper function definitions (private functions)
5. Exported functions (attached to M)
6. Return statement (`return M`)

**Example from `shots.lua`:**
```lua
-- Shot detection and management for shooter.nvim
-- Finding, marking, and parsing shots in shooter files

local utils = require('shooter.utils')
local config = require('shooter.config')

local M = {}

-- Check if a line is inside a code block (count ``` markers above)
local function is_in_code_block(lines, line_num) ... end

function M.find_current_shot(bufnr, cursor_line) ... end
```

**Path Aliases:**
- None detected in codebase; uses direct relative requires: `require('shooter.utils')`, `require('shooter.core.shots')`
- Absolute paths from plugin root (lua/shooter/)

## Error Handling

**Patterns:**
- Return tuple pattern: `(success, error_msg)` or `(result, error_msg, extra_info)` - see `rename.lua:perform_rename()`
- Nil returns for missing data: `function M.find_current_shot()` returns `nil, nil, nil` when no shot found
- System error checking: `if vim.v.shell_error == 0 and #result > 0 then` after `systemlist()` calls
- File operation guards: Check file existence before reading: `if not file then return nil, msg end`
- Optional dependency handling via pcall: `local ok, oil = pcall(require, 'oil')` to safely load optional modules

**User Notifications:**
- Non-critical messages via `utils.echo()` (shows in command line)
- Important messages via `utils.notify()` with log level: `vim.log.levels.WARN`, `vim.log.levels.ERROR`, `vim.log.levels.INFO`
- Errors in callbacks use notify: `utils.notify('File already exists: ' .. new_filename, vim.log.levels.ERROR)`

## Logging

**Framework:** `vim.notify` via `utils.notify()` helper

**Patterns:**
- Log on start of operations: "No file selected", "Not in a shooter file"
- Log on completion: "Renamed to ..." with additional context
- Log errors with specific reason: "File already exists: X" not just "Error"
- Use log levels consistently:
  - `vim.log.levels.ERROR` for failures blocking operation
  - `vim.log.levels.WARN` for non-fatal issues
  - `vim.log.levels.INFO` for operational status

**No logging inside library functions** - functions like `find_current_shot()`, `get_shot_content()` return values; callers decide what to notify.

## Comments

**When to Comment:**
- Above functions: Describe what function does, parameters, and returns
- On complex logic: Explain algorithm or non-obvious pattern matching
- CRITICAL sections: Mark areas where order/timing matters (see `rename.lua:120` - buffer must close before file rename)
- Skip obvious code: No comment needed for `if condition then return end` guards

**Style:**
- Single-line comments: `-- Comment here`
- Above function definitions for public APIs
- Inline comments on complex regex patterns or timestamps

**Example from `rename.lua`:**
```lua
-- CRITICAL: Save and close the buffer before modifying file on disk
-- This prevents content loss when Neovim's buffer state conflicts with disk state
```

## Function Design

**Size:**
- Typical range: 15-40 lines
- Larger files split by namespace (e.g., `commands.lua` at 634 lines is split across namespaces)
- Complex operations extract helpers: `is_in_code_block()` helper in `shots.lua`

**Parameters:**
- Typically 1-3 parameters
- Optional parameters use default pattern: `local arg = arg or default_value`
- Context parameters often optional: `bufnr = bufnr or 0` (0 = current buffer), `cursor_line = cursor_line or utils.get_cursor()[1]`
- No long parameter lists; complex data passed as tables

**Return Values:**
- Single return for simple getters: `return result`
- Tuple returns for operations: `return success, error_msg` or `return value, error_msg, metadata_table`
- Multiple returns separated by commas: `local start, finish, header = shots.find_current_shot(bufnr, 3)`

## Module Design

**Exports:**
- All public functions attached to M table: `function M.my_function() end`
- Private functions use `local function` and not attached to M
- Single export statement at end: `return M`

**Barrel Files:**
- Minimal barrel pattern; some aggregation in `tmux/init.lua`:
  ```lua
  M.detect = require('shooter.tmux.detect')
  M.send = require('shooter.tmux.send')
  ```
- Most modules are single-responsibility, no re-exports

**Dependency Injection:**
- Some functions receive modules as parameters for testability: `operations.send_current_shot(pane_index, M.detect, M.send, M.messages)`
- Allows mocking in tests and decouples responsibility

---

*Convention analysis: 2026-01-30*

---

# Coding Standards

Universal coding standards for all languages and projects.

## Clarity

- Write clean, readable code; prefer clarity over cleverness
- Functions should do one thing and be short enough to understand at a glance
- Use meaningful, descriptive names for variables, functions, and files
- Code should read like prose — a new developer should follow the logic without comments

## Structure

- One concept per function; one responsibility per module
- Keep nesting shallow (max 2-3 levels); extract early returns or helper functions
- Order code top-down: public API first, helpers below
- Group related logic together; separate unrelated concerns

## Naming

- Variables: describe what it holds (`userCount`, not `n`)
- Functions: describe what it does (`fetchUserProfile`, not `getData`)
- Booleans: use `is`/`has`/`should` prefixes (`isActive`, `hasPermission`)
- Files: match the primary export or concept they contain

## Constants and Magic Values

- No magic numbers or strings — use named constants
- Group related constants in enums or constant objects
- Configuration values belong in config files, not scattered in code

## DRY and Abstraction

- DRY applies at 3+ repetitions; don't abstract after the first duplication
- Three similar lines of code beats a premature abstraction
- Prefer composition over inheritance
- Extract when you have a clear, stable interface — not before

## Error Handling

- Validate at system boundaries (API inputs, file reads, user data)
- Trust internal code — don't defensively check everything
- Fail fast with clear error messages
- Handle errors at the level that can do something useful about them
- Never swallow errors silently

## Code Hygiene

- No commented-out code — git history preserves everything
- No dead code; delete unused functions and imports
- Avoid premature optimization — measure first, optimize second
- TODO comments should be actionable and resolved promptly, or be removed
- Keep files under 300 lines; split when they grow beyond that

## Dependencies

- Prefer standard library over third-party when the gap is small
- Evaluate dependencies for maintenance status and bundle size
- Pin dependency versions for reproducible builds
- One package manager per project — no mixing npm/yarn/pnpm

---

# Security Rules

Security practices required across all projects and languages. These rules align with the [OWASP Top 10 2021](https://owasp.org/Top10/) security risks.

## Secrets Management

- Never commit secrets, keys, tokens, or passwords to version control
- Use environment variables or secret managers for sensitive configuration
- Add secret patterns to `.gitignore` and use git pre-commit hooks to catch leaks
- Rotate any credential that was ever exposed, even briefly
- Use `.env.example` with placeholder values, never real secrets

## Input Validation

*Addresses A03:2021 Injection*

- Validate all user input at system boundaries
- Never trust client-side validation alone — always validate server-side
- Use allowlists over denylists for input validation
- Reject unexpected input; don't try to sanitize it into validity
- Validate types, ranges, lengths, and formats

## Output Security

*Addresses A03:2021 Injection*

- Sanitize all output to prevent XSS (cross-site scripting)
- Use context-aware encoding (HTML, URL, JavaScript, CSS)
- Set `Content-Security-Policy` headers
- Escape user-generated content before rendering

## Database Security

*Addresses A03:2021 Injection*

- Use parameterized queries — never concatenate SQL strings
- Apply principle of least privilege to database accounts
- Never expose raw database errors to users
- Sanitize and validate all query parameters

## Authentication and Authorization

*Addresses A01:2021 Broken Access Control, A07:2021 Identification and Authentication Failures*

- Follow principle of least privilege for all access
- Use established auth libraries — never roll your own crypto
- Hash passwords with bcrypt/argon2 — never SHA/MD5
- Implement rate limiting on auth endpoints
- Use short-lived tokens; implement refresh token rotation

## Dependency Security

*Addresses A06:2021 Vulnerable and Outdated Components*

- Keep dependencies updated; automate vulnerability scanning
- Audit new dependencies before adding them
- Use lockfiles for reproducible builds
- Pin versions in production

## Code Safety

*Addresses A03:2021 Injection, A08:2021 Software and Data Integrity Failures*

- No `eval()` or dynamic code execution from user input
- No deserialization of untrusted data
- Avoid shell command injection — use library APIs instead of exec
- Disable debug mode and verbose errors in production

## Infrastructure

*Addresses A05:2021 Security Misconfiguration, A09:2021 Security Logging and Monitoring Failures*

- HTTPS everywhere — no exceptions
- Set secure cookie flags: `HttpOnly`, `Secure`, `SameSite`
- Implement CORS with specific origins, not wildcards
- Log security events; never log sensitive data

---

# Commit Conventions

Git commit standards for all repositories.

## Format

```
type(scope): description

Optional body explaining WHY, not WHAT.

Co-Authored-By: <name> <email>
```

## Subject Line

- Use conventional commits: `type(scope): description`
- Keep under 72 characters
- Use imperative mood: "add feature" not "added feature"
- Lowercase after the colon

## Types

| Type       | When to use                        |
|------------|------------------------------------|
| `feat`     | New feature or capability          |
| `fix`      | Bug fix                            |
| `refactor` | Code change that doesn't fix/add   |
| `docs`     | Documentation only                 |
| `chore`    | Maintenance, deps, config          |
| `test`     | Adding or updating tests           |
| `ci`       | CI/CD pipeline changes             |
| `perf`     | Performance improvement            |
| `style`    | Formatting, whitespace, lint fixes |

## Scope

- Use the module, package, or feature area: `feat(auth): add login`
- Use the project name for cross-cutting: `chore(ai): update rules`
- Omit scope only for truly global changes

## Body

- Separate from subject with a blank line
- Explain WHY the change was made, not WHAT changed (the diff shows that)
- Wrap at 72 characters
- Reference related issues or context

## Trailers

- **Co-Authored-By** (required for AI commits): `Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>`
- Place trailers after the body, separated by a blank line

## Rules

- One logical change per commit — don't mix refactoring with features
- Never commit broken code to main
- Squash fixup commits before merge
- Rebase feature branches; merge to main

---

# Multi-Agent Conventions

Rules for coordinating work across AI coding agents. All agents operating in repos that use the ai ruleset MUST follow these conventions.

---

## GSD Workflow Integration

This project uses GSD (Get Shit Done) for task tracking and project management. GSD provides phases, plans, todos, and persistent state across sessions.

---

## 1. Agent Identification

Every agent session should be identifiable. Use the Co-Authored-By trailer in commits to identify which agent performed the work.

| Agent | Co-Authored-By |
|-------|----------------|
| Claude Code (Opus 4.5) | `Claude Opus 4.5 <noreply@anthropic.com>` |
| Claude Code (Sonnet 4) | `Claude Sonnet 4 <noreply@anthropic.com>` |
| OpenCode (GPT-5.2 Codex) | `GPT-5.2 Codex <noreply@openai.com>` |
| OpenCode (Gemini 3 Pro) | `Gemini 3 Pro <noreply@google.com>` |
| Gemini CLI | `Gemini CLI <noreply@google.com>` |
| Codex CLI | `Codex CLI <noreply@openai.com>` |
| Kimi CLI | `Kimi CLI <noreply@moonshot.cn>` |
| Human | N/A |

---

## 2. Commit Convention

Every commit should follow conventional commits with a `Co-Authored-By` trailer for AI-authored commits.

Format:
```
<type>(<scope>): <description>

Co-Authored-By: <Agent Name> <noreply@provider.com>
```

Example:
```
feat(rules): add typescript standards

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

Rules:
- `<type>` follows conventional commits: feat, fix, refactor, docs, chore, test, ci, perf, style
- `<scope>` is the area of the codebase affected
- `Co-Authored-By` is required for all AI-generated commits

---

## 3. Session Handoff Protocol

### Ending a session

1. Complete current work
2. Commit changes with clear message
3. Push: `git push`

### Starting a session

1. Pull latest: `git pull`
2. Check GSD progress: `/gsd:progress`
3. Find ready work: `/gsd:check-todos` or `/gsd:ready`
4. Continue from where previous session left off

---

## 4. Progress Tracking with GSD

AI agents should use GSD commands for progress tracking:

- `/gsd:progress` — Check project progress and current state
- `/gsd:check-todos` — List pending todos and select one to work on
- `/gsd:add-todo` — Capture ideas or tasks from conversation context
- `/gsd:pause-work` — Create context handoff when pausing mid-phase
- `/gsd:resume-work` — Resume work from previous session

### When working on a task:

1. **Check status**: `/gsd:progress`
2. **Select work**: `/gsd:check-todos`
3. **Execute**: Do the work
4. **Commit**: Atomic commits as you go

---

## 5. Context Rot Prevention

These rules prevent stale context and duplicated sources of truth across multi-agent workflows.

1. **Single source of truth**: GSD owns progress and state. Plan files own design. Never duplicate progress in both.
2. **No orphan work**: Capture significant work items with `/gsd:add-todo` immediately when you discover something that needs doing.
3. **File findings immediately**: When you discover bugs, inconsistencies, or improvements during reviews — either fix them or add a todo.
4. **Session handoff protocol**: Always follow the ending/starting procedures in section 3. No silent session exits.
5. **Plan file is a blueprint**: After implementation starts, plan files are only updated for design changes.

---

## 6. Consistency Across Repos

All repositories under `~/a/` should use consistent tooling configuration.

1. **GSD initialization**: Projects using GSD should have `.planning/` directory with GSD state
2. **Git ignore patterns**: Every repo ignores `.ai-rules/` and runtime files
3. **Context file wiring**: Every repo has `.ai-context.md` referenced at the top of `CLAUDE.md` and `GEMINI.md`

---

## 7. Shot Workflow

See `rules/core/shot-workflow.md` for full rules.

Key points: shotfiles are **read-only input**. Track execution via GSD or git commits, never write back to the shotfile.

---

## 8. Artifact Persistence

See `rules/core/artifact-persistence.md` for full rules.

Key points: all AI output of lasting value must be persisted to the filesystem. Research goes to `plans/research/`, plans to `plans/<cli-name>/`. Different CLIs write to separate subdirectories to avoid conflicts.

---

## 9. Plan Mode Workflow

When working with plans, use GSD for execution tracking:

### For new projects:
- `/gsd:new-project` — Initialize project with deep context gathering

### For phases:
- `/gsd:plan-phase` — Create detailed execution plan for a phase
- `/gsd:execute-phase` — Execute plans with atomic commits

### For quick tasks:
- `/gsd:quick` — Execute quick task with GSD guarantees but skip optional agents

---

# Shot Workflow Rules

Rules for processing shots (task instructions) from plan files.

## Core Principle

Shotfiles are **read-only input**. Never modify the source shot file.

## Workflow

1. **Receive** a shot from `plans/prompts/` or a plan file
2. **Execute** the work described in the shot
3. **Commit** changes with a clear commit message referencing the shot
4. **Push** to persist the work

## Rules

- **NEVER write back to the shotfile** — it is immutable input
- Track execution via git commits, not by modifying the shot
- If a shot requires multiple steps, make atomic commits as you go
- If a shot is blocked, note the blocker and communicate to the user
- Reference the shot source in commit messages for traceability

## Shot Sources

- `plans/prompts/*.md` — standalone shot files
- Inline shots within plan documents
- Shots may reference other shots; follow the dependency chain

## Output

- All work products go to their designated locations (see `artifact-persistence.md`)
- Git commits capture what was done and decisions made
- Never leave work untracked — if you did it, commit it

---

## Session Close Protocol

```bash
git status              # Check what changed
git add <files>         # Stage code changes
git commit -m "..."     # Commit code
git push                # Push to remote
```
