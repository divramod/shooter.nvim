# AI Agent Configuration

Source: ~/a/ai v0.1.0 | Generated: 2026-01-30

> For OpenCode and Codex CLI. Claude Code uses CLAUDE.md, Gemini CLI uses GEMINI.md.

---

# Human Context

<!-- This file is for human-written project context. AI agents should NEVER edit this file. -->

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

### CONCERNS

# Codebase Concerns

**Analysis Date:** 2026-01-30

## Tech Debt

**Shell Command Injection Risk in String Concatenation:**
- Issue: Multiple locations concatenate user paths/input directly into shell commands without proper escaping
- Files: `lua/shooter/analytics/data.lua`, `lua/shooter/analytics/init.lua`, `lua/shooter/tmux/detect.lua`, `lua/shooter/tmux/panes.lua`, `lua/shooter/tmux/send.lua`, `lua/shooter/images.lua`, `lua/shooter/providers/init.lua`
- Impact: If a user creates a file path with shell metacharacters or a project name contains backticks/semicolons, arbitrary code execution is possible. Example: `io.popen('ls -d "' .. expanded_dir .. '"/*/ 2>/dev/null')` at line 146 in `analytics/data.lua`
- Fix approach: Use Lua path escaping library (e.g., `vim.fn.shellescape()`) or switch to direct APIs. Replace all manual string.format tmux commands with proper argument arrays

**Temporary File Cleanup Race Condition:**
- Issue: Temporary files created in `tmux/send.lua` are deleted via shell command at end of compound command chain. If any command fails before the `rm`, temp file orphans persist
- Files: `lua/shooter/tmux/send.lua` lines 94, 159
- Impact: Disk space leakage; over time, `/tmp` fills with abandoned files containing user prompts (potential privacy issue)
- Fix approach: Use Lua file API with cleanup in error handler, or use a cleanup registry that periodically removes orphaned files older than 1 hour

**Hardcoded Wait Channel Names:**
- Issue: Wait channel names for tmux coordination are predictable and not namespaced
- Files: `lua/shooter/images.lua` lines 40-41
- Impact: In multi-user systems or parallel nvim instances, collision is possible causing race conditions
- Fix approach: Generate unique channel names using pid: `string.format('shooter_%d_%d', vim.fn.getpid(), os.time())`

## Known Bugs

**Renumber Command Does Not Validate Shot Patterns:**
- Symptoms: `ShooterShotsRenumber` may miss or miscount shots if shot headers deviate slightly from expected format (e.g., trailing spaces, mixed case)
- Files: `lua/shooter/core/renumber.lua`
- Trigger: Create a shot header with variations like `## shot` vs `##shot` or `## SHOT` (uppercase)
- Workaround: Ensure consistent shot header formatting before running renumber

**io.popen Handle Not Closed on Early Return:**
- Symptoms: File descriptor leak if function returns before handle:close() is called
- Files: Multiple locations - `lua/shooter/analytics/data.lua` (lines 146, 177, 197), `lua/shooter/health.lua` (lines 87, 111, 226), `lua/shooter/tmux/panes.lua` (lines 21, 33, 53)
- Trigger: When io.popen succeeds but subsequent code path returns early without explicit close
- Workaround: Always store handle and ensure close() is called; use defer/finally pattern where possible

**Outdated Session File Can Break Picker:**
- Symptoms: Shot picker fails to load if session YAML file has missing or corrupted vimMode/filters/sortBy sections
- Files: `lua/shooter/session/storage.lua` (parse_yaml function)
- Trigger: Manual session file edits or corrupted YAML from previous versions
- Workaround: Delete problematic session file at `~/.config/shooter.nvim/sessions/<repo>/` to regenerate defaults

## Security Considerations

**User Input From File Paths Not Escaped in Shell Commands:**
- Risk: Project names and file paths passed to tmux/shell commands are not shell-escaped. A project named `test; rm -rf /` in `projects/` would execute arbitrary commands
- Files: `lua/shooter/core/project.lua` (line 45), `lua/shooter/core/repos.lua` (line 39), `lua/shooter/telescope/helpers.lua` (lines 323, 346)
- Current mitigation: Filesystem path constraints (only characters allowed in directory names), but not sufficient if user creates adversarial paths
- Recommendations: Use `vim.fn.shellescape()` for all file/directory paths before passing to shell; validate project names at creation time

**Git Remote URL Parsing Not Validated:**
- Risk: `analytics/data.lua` line 96 uses regex to parse git URLs. Malformed URLs could match unexpectedly or be used to inject commands if passed to shell
- Files: `lua/shooter/analytics/data.lua` (lines 84-100)
- Current mitigation: Only used for display, not executed as commands
- Recommendations: Validate git URL format strictly; use `git config` API instead of parsing URLs

**Temp File Paths Predictable:**
- Risk: Temp files created with `os.tmpname()` in `tmux/send.lua` line 67 are created in system temp directory. On multi-user systems, another user could intercept/read shot contents before they're deleted
- Files: `lua/shooter/tmux/send.lua` (line 67)
- Current mitigation: Files are deleted after tmux paste, but timing window exists
- Recommendations: Create files in user-only-readable directory (mode 0600); use vim plugin temp dir if available

## Performance Bottlenecks

**Analytics Data Parsing Loads Entire Shotfile Into Memory:**
- Problem: `analytics/data.lua` line 36 reads entire file with `io.read('*a')`, then iterates line-by-line. For very large shotfiles (>10MB), this causes memory spike
- Files: `lua/shooter/analytics/data.lua` (lines 33-80)
- Cause: No streaming/chunked parsing; entire file in memory before processing
- Improvement path: Process file line-by-line without loading full content; count shots in first pass, extract metrics only for requested range

**Picker Refresh on Every Folder Toggle:**
- Problem: `telescope/pickers.lua` (lines 58-63) refreshes entire picker state when user toggles folders. For repos with 1000+ shots, this causes UI stall
- Files: `lua/shooter/telescope/pickers.lua` (setup_folder_mappings function)
- Cause: Full file list regenerated instead of filtering in-place
- Improvement path: Cache file list; implement filter-only refresh that applies state without reloading filesystem

**io.popen With External Commands Has 2-3 Second Latency:**
- Problem: Multiple `io.popen()` calls to tmux/shell commands throughout codebase introduce cumulative delay. Health check spawns 10+ processes
- Files: `lua/shooter/health.lua` (check functions), `lua/shooter/tmux/detect.lua` (list_all_panes), `lua/shooter/providers/init.lua`
- Cause: Each call forks a process; no batching of related calls
- Improvement path: Batch health checks (single tmux call that returns all pane info); cache results with TTL

## Fragile Areas

**Tmux Integration Assumes Specific Pane Format:**
- Files: `lua/shooter/tmux/detect.lua`, `lua/shooter/tmux/panes.lua`, `lua/shooter/providers/init.lua`
- Why fragile: Code assumes `#{pane_tty}` format matches `ttys\d+` pattern (line 80 in detect.lua). If user has custom tmux config that changes pane output format, all pane detection breaks silently
- Safe modification: Add defensive regex matching; log warnings when format doesn't match expected pattern; add option to manually specify pane ID
- Test coverage: No tests verify pane detection with non-standard tmux configs

**Session YAML Parsing Is Manual and Brittle:**
- Files: `lua/shooter/session/storage.lua` (parse_yaml function, lines 78-160)
- Why fragile: Hand-rolled YAML parser only handles specific indentation/structure. Any deviation breaks (e.g., extra spaces, tabs vs spaces, missing keys)
- Safe modification: Use a YAML library (e.g., lyaml) or switch to JSON for sessions; add validation with clear error messages for malformed files
- Test coverage: Only happy-path tested; no tests for truncated/malformed YAML

**File Pattern Matching Uses Global Glob With No Size Limits:**
- Files: `lua/shooter/core/files.lua` (line 93 - globpath returns all results at once)
- Why fragile: If a user accidentally creates prompts directory with 100k+ files, `vim.fn.globpath()` call will consume all memory and freeze nvim
- Safe modification: Implement pagination/streaming; add file count limits with warning; check directory size before globbing
- Test coverage: No stress tests with large file counts

**Commands.lua Has 634 Lines With Deep Nesting:**
- Files: `lua/shooter/commands.lua`
- Why fragile: Large command registration functions (setup_shotfile_commands: 152 lines, setup_shot_commands: 111 lines) with nested callbacks and closures make it hard to trace data flow or add new commands without breaking existing ones
- Safe modification: Split into per-namespace files; move inline command logic to separate module functions; extract common patterns
- Test coverage: Commands are registered but not tested for correctness; no tests verify callback behavior

**Oil.nvim Integration Uses Unsafe File Retrieval:**
- Files: `lua/shooter/core/files.lua` (lines 23-31, 43-58)
- Why fragile: Code uses `pcall(require, 'oil')` inline but doesn't validate that oil is actually loaded; relies on entry being present under cursor (nil if empty dir)
- Safe modification: Validate oil availability at startup; add null checks before accessing entry.name/entry.type; provide fallback to normal buffer mode
- Test coverage: No tests with oil unavailable; no tests with empty directories

## Scaling Limits

**Analytics Report Generation Doesn't Paginate:**
- Current capacity: Reasonable for <5000 executed shots across all repos
- Limit: At 50k executed shots, analytics data loading freezes UI for 5+ seconds; memory usage exceeds 100MB
- Scaling path: Implement date-range filtering; cache aggregates by month; lazy-load metrics on demand

**Picker State Multiplied by Session Count:**
- Current capacity: ~3-5 sessions per repo
- Limit: At 20+ saved sessions, loading session list and switching becomes O(n) slow; session picker becomes unusable
- Scaling path: Lazy-load sessions; archive old sessions; implement session search/filter

**Tmux Pane Detection Linear Scan:**
- Current capacity: <20 panes
- Limit: At 50+ tmux panes (multi-monitor setups), pane detection loops take >500ms
- Scaling path: Cache pane list with TTL; use tmux server API if available; optimize grep filter

## Dependencies at Risk

**Manual YAML Parsing (No YAML Library):**
- Risk: Session serialization is custom YAML parser/writer. If data structure changes, serialization breaks. No validation of parse success
- Impact: Session data loss; user configurations reset to defaults unexpectedly
- Migration plan: Add `lyaml` dependency (pure Lua, no external deps) or switch to JSON format with json.lua library

**io.popen Relies on Shell Availability:**
- Risk: Code assumes `/bin/sh` and standard Unix utilities (find, grep, ls, tmux) are available. On Windows WSL or minimal environments, these may not exist
- Impact: All tmux/shell-based features fail silently with unclear errors
- Migration plan: Detect missing commands at health check time; provide fallback implementations or Windows-compatible alternatives

**git Command Dependency Not Validated:**
- Risk: Multiple calls to `git rev-parse`, `git remote get-url` assume git is in PATH. No error handling for git not found
- Impact: Plugin initialization fails silently if git is missing; error messages are unclear
- Migration plan: Add git availability check to health check; wrap git calls with error handler

## Test Coverage Gaps

**Untested: Tmux Send/Integration with Real Tmux:**
- What's not tested: Actual sending of text to tmux panes; temp file creation/deletion; escape sequence handling
- Files: `lua/shooter/tmux/send.lua`, `lua/shooter/tmux/create.lua`, `lua/shooter/tmux/keys.lua`
- Risk: Send operations could fail silently or corrupt pane state without detection
- Priority: High - core feature depends on this

**Untested: Analytics Parsing Edge Cases:**
- What's not tested: Shotfiles with malformed shot headers; files with Unicode; very large shot content (>1MB); symlinks in prompts dir
- Files: `lua/shooter/analytics/data.lua`
- Risk: Analytics report crashes or produces wrong metrics without warning
- Priority: Medium

**Untested: Session Persistence Across Versions:**
- What's not tested: Loading session files created by older plugin versions; migration of session format; corrupted YAML recovery
- Files: `lua/shooter/session/storage.lua`
- Risk: User sessions lost after plugin update; no recovery path
- Priority: Medium

**Untested: Oil.nvim Interop:**
- What's not tested: File retrieval when oil.nvim is loaded; behavior when oil not available; symlinks/special files in oil
- Files: `lua/shooter/core/files.lua`, `lua/shooter/keymaps/oil.lua`
- Risk: Oil-based commands fail silently; keymaps don't work in oil buffers
- Priority: Medium

**Untested: Multi-Pane Send With Timing:**
- What's not tested: Sending large shots (>10k chars) to multiple panes in sequence; cleanup if send to pane 1 succeeds but pane 2 fails
- Files: `lua/shooter/tmux/init.lua`, `lua/shooter/tmux/send.lua`
- Risk: Partial send state corruption; orphaned temp files; stuck panes
- Priority: High

---

*Concerns audit: 2026-01-30*

### INTEGRATIONS

# External Integrations

**Analysis Date:** 2026-01-30

## APIs & External Services

**AI Providers:**
- **Claude Code CLI** - Primary AI integration for sending shots
  - SDK/Client: Direct CLI invocation via tmux send
  - File path format: `@filepath` syntax support in `lua/shooter/providers/claude.lua`
  - Detection: Process pattern matching `claude`
  - Location: `lua/shooter/providers/claude.lua` (lines 1-46)

- **OpenCode CLI** - Alternative AI provider (supported in parallel)
  - Implementation: `lua/shooter/providers/opencode.lua`
  - Same message sending interface as Claude provider
  - Process pattern matching for detection

## Data Storage

**Databases:**
- None - Shooter.nvim is a stateless plugin (no persistent data backend)

**File Storage:**
- **Local filesystem only**
  - Shot files: Markdown format in `plans/prompts/` (user configurable in `lua/shooter/config.lua`)
  - Session files: YAML format in `~/.config/shooter.nvim/sessions/<owner>_<repo>/` per-repository
  - Queue file: JSON format at `plans/prompts/.shot-queue.json`
  - Images: `~/.clipboard-images/` or `.shooter.nvim/images/` (configurable)
  - Context files: Global `~/.config/shooter.nvim/shooter-context-global.md` and project `.shooter.nvim/shooter-context-project.md`

**Session Persistence:**
- **Format:** YAML (custom serializer in `lua/shooter/session/storage.lua`)
- **Location:** `~/.config/shooter.nvim/sessions/`
- **Schema:** `lua/shooter/session/defaults.lua`
  - vimMode settings (shotfilePicker, projectPicker, sortPicker modes)
  - Filters (projects root/sub, folders)
  - Sort criteria with priority and direction
  - Layout preference (vertical/horizontal)
- **Operations:** `lua/shooter/session/picker.lua`, `lua/shooter/session/init.lua`

**Caching:**
- Filter state cache in memory: `lua/shooter/filter_state.lua` (not persistent)
- No external cache service

## Authentication & Identity

**Auth Provider:**
- None - Plugin uses host system context (Git, tmux user, etc.)
- No user login required

**AI Provider Access:**
- Claude Code CLI runs in authenticated tmux pane
- Credentials handled by Claude CLI process, not by shooter.nvim
- Shot content + context sent as plain text via tmux

## Monitoring & Observability

**Error Tracking:**
- None - Plugin uses Neovim notifications for user feedback
- Notifications via `vim.notify()` throughout codebase

**Logs:**
- **Health Check:** `lua/shooter/health.lua`
  - Verifies: Plugin initialization, Neovim version, Telescope installed, Tmux available
  - Checks: Claude/OpenCode CLI running, Git available, Obsidian vault present
  - Checks: Optional tools (ttok, hal, gp.nvim)
- **Shell Execution Tracking:** `lua/shooter/tmux/send.lua` calculates delays for message transmission
- **Execution Status:** Shots marked with timestamp when executed (inline in markdown files)

**Debug Information:**
- Available via `:ShooterHealth` command (registered in `lua/shooter/commands.lua`)
- No verbose logging output; relies on notifications

## File System Interaction

**Path Resolution:**
- Git root detection: `git rev-parse --show-toplevel` (in `lua/shooter/core/files.lua`)
- Relative path computation for panes and projects
- Symlink expansion for config directories
- Environment variable expansion: `~/.config/`, `~/.clipboard-images/` via `vim.fn.expand()`

**File Operations:**
- **Reading:** Markdown shot files with pattern matching
  - Shot header pattern: `^##\s+x?\s*shot` (open or executed)
  - Markdown parsing in `lua/shooter/core/shots.lua`
- **Writing:** Shot execution marking (adds `x` prefix and timestamp)
- **Directories:** Creation via `vim.fn.mkdir(path, 'p')` (recursive)

## CI/CD & Deployment

**Hosting:**
- GitHub repository: `divramod/shooter.nvim`
- Plugin registry: Lazy.nvim, Packer.nvim compatible

**CI Pipeline:**
- Plenary.nvim testing: `:PlenaryBustedDirectory tests/`
- No automated CI service configured (local testing only)

**Distribution:**
- Plugin uploaded to GitHub releases
- Installed via plugin managers pointing to GitHub repo

## Environment Configuration

**Required env vars:**
- `TMUX` - Checked to detect if running in tmux session (optional but required for send functionality)
- `HOME` - Used for config directory paths

**Optional env vars:**
- `CLAUDE_*` - Claude CLI authentication (handled by Claude CLI process)

**Secrets location:**
- No secrets stored in plugin code
- AI credentials managed by tmux pane running Claude CLI
- All text transmission is plain text through tmux buffer

## Webhooks & Callbacks

**Incoming:**
- None - Plugin is event-driven by user actions in Neovim

**Outgoing:**
- **Tmux Send Events:** Shots sent to tmux panes via `tmux send-keys` command
  - Implementation: `lua/shooter/tmux/send.lua`
  - Escape sequence handling: `vim.fn.system()` execution of tmux commands
  - Temporary file usage for large messages (content written to `/tmp/` via `os.tmpname()`)

## External Tool Integration Points

**Obsidian:**
- Vault detection: Walking up directory tree looking for `.obsidian/` directory
- URI scheme: `obsidian://open?vault=<name>&file=<path>` in `lua/shooter/tools/obsidian.lua`
- Activation: `open` (macOS) or `xdg-open` (Linux)
- Location: `lua/shooter/tools/obsidian.lua` (lines 1-102)

**Token Counter (ttok CLI):**
- Command: `ttok < filename` (piped input)
- Output: Plain number (token count)
- Error handling: Checks if `ttok` is executable (`vim.fn.executable('ttok')`)
- Location: `lua/shooter/tools/token_counter.lua`

**Image Handling:**
- **Clipboard Detection:** `scripts/shooter-clipboard-image check` (exit code 0 if image in clipboard)
- **Image Saving:** `scripts/shooter-clipboard-image save <directory>`
- **Clipboard Script:** Located at `scripts/shooter-clipboard-image` (bash script)
- **Implementation:** `lua/shooter/tools/clipboard_image.lua`
- **Integration:** Smart paste on `p`, `P`, `Ctrl-V` in keymaps (`lua/shooter/keymaps.lua`)

**Voice Input (gp.nvim Optional):**
- If gp.nvim installed: `<space>e` triggers voice dictation
- Conditional loading in `lua/shooter/keymaps.lua` (graceful fallback if not installed)

**Image Picking (hal CLI Optional):**
- Command: `hal` CLI invocation for image selection
- Used with `<space>I` command for image insertion
- Health check in `lua/shooter/health/tools.lua`
- Implementation: `lua/shooter/images.lua`

## System Command Integration

**Tmux Commands Used:**
- `tmux send-keys -t <pane> <text>` - Send text to pane
- `tmux split-window` - Create new pane
- `tmux list-panes -F` - List available panes with format
- `tmux display-message` - Get pane information
- `tmux resize-pane` - Resize panes
- Implementation: `lua/shooter/tmux/operations.lua`, `lua/shooter/tmux/wrapper.lua`

**Git Commands Used:**
- `git rev-parse --show-toplevel` - Get repository root
- Usage: `lua/shooter/core/files.lua`, `lua/shooter/tools/clipboard_image.lua`

**System Utilities:**
- `ls -1`, `ls -d` - Directory listing
- `find` - File discovery
- `ps aux | grep` - Process detection
- Shell execution via `io.popen()`, `vim.fn.system()`, `os.execute()`
- Locations: `lua/shooter/core/repos.lua`, `lua/shooter/health.lua`, `lua/shooter/providers/init.lua`

## Message Flow Architecture

**Shot Sending Pipeline:**
1. User selects shot in telescope picker
2. Message builder: `lua/shooter/tmux/messages.lua` constructs message with context
3. Context injection: `lua/shooter/core/context.lua`, `lua/shooter/context/resolvers.lua`
4. Delay calculation based on message size: `lua/shooter/tmux/send.lua`
5. Temporary file write for large messages: `lua/shooter/tmux/send.lua` (lines 66-75)
6. Tmux execution: `vim.fn.system()` with `tmux send-keys` command
7. Escape sequences: Clear line, reset state before sending

**Multi-shot Sending:**
- Similar flow but with multishot delay calculation
- Implementation: `lua/shooter/tmux/operations.lua`

## Configuration File Formats

**YAML Sessions:**
- Custom parser/serializer (no external YAML library)
- Fields: `name`, `vimMode`, `filters`, `sortBy`, `layout`
- Location: `lua/shooter/session/storage.lua` (lines 44-73 serialize, 78-152 parse)

**JSON Queue:**
- Queue file format for batched shot execution
- Location: `plans/prompts/.shot-queue.json` (default)
- Structure: `lua/shooter/queue/storage.lua`

**Markdown Shot Files:**
- Format: Headers with `## shot N` or `## x shot N` (executed)
- Timestamp appended on execution: `[timestamp: YYYY-MM-DD HH:MM:SS]`
- Context files in markdown with template injection
- Parser: `lua/shooter/core/shots.lua`

**Context Templates:**
- Global template: `~/.config/shooter.nvim/shooter-context-global.md`
- Project template: `.shooter.nvim/shooter-context-project.md`
- Message template: `templates/shooter-context-message.md`
- Template variables: Repository name, file paths, shot header
- Processing: `lua/shooter/core/templates.lua`, `lua/shooter/tmux/messages.lua`

---

*Integration audit: 2026-01-30*

### TESTING

# Testing Patterns

**Analysis Date:** 2026-01-30

## Test Framework

**Runner:**
- plenary.nvim (Lua testing library for Neovim plugins)
- Uses busted-style syntax (describe/it/before_each/after_each)
- Invoked via Neovim command: `:PlenaryBustedDirectory tests/`

**Assertion Library:**
- plenary's built-in assertions via `assert`
- Common assertions: `assert.are.equal()`, `assert.is_nil()`, `assert.is_truthy()`, `assert.is_function()`, `assert.is_table()`

**Run Commands:**
```bash
:PlenaryBustedDirectory tests/              # Run all tests
:PlenaryBusted tests/core/shots_spec.lua    # Run specific test file
```

No automated CI test runner detected in repository; tests are run manually in Neovim.

## Test File Organization

**Location:**
- Tests co-located with source in `tests/` directory mirroring `lua/shooter/` structure
- Test files in: `tests/core/`, `tests/tmux/`, `tests/telescope/`, `tests/tools/`, `tests/dashboard/`, `tests/providers/`

**Naming:**
- Pattern: `<module>_spec.lua` for each source module
- Example: `lua/shooter/core/shots.lua` → `tests/core/shots_spec.lua`
- 25 test files total covering all major modules

**Structure:**
```
tests/
├── core/
│   ├── shots_spec.lua
│   ├── project_spec.lua
│   ├── analytics_spec.lua
│   └── ...
├── tmux/
│   ├── shell_spec.lua
│   ├── init_spec.lua
│   └── ...
├── tools/
│   ├── token_counter_spec.lua
│   └── ...
```

## Test Structure

**Suite Organization:**
```lua
-- Test suite for shooter.core.shots module
local shots = require('shooter.core.shots')

describe('shots module', function()
  before_each(function()
    -- Set up test environment
  end)

  after_each(function()
    -- Clean up
  end)

  describe('find_current_shot', function()
    it('finds shot at cursor position', function()
      -- Arrange: Create test buffer
      -- Act: Call function
      -- Assert: Verify result
    end)
  end)
end)
```

**Patterns:**
- `describe()` blocks organize tests by function or feature
- `it()` blocks describe single test case
- `before_each()` for setup before each test
- `after_each()` for cleanup (usually empty)
- Test names read as behavior: "finds shot at cursor position", "returns nil when no shot found"

**Example from `shots_spec.lua`:**
```lua
describe('shots module', function()
  describe('find_current_shot', function()
    it('finds shot at cursor position', function()
      -- Create test buffer with shots
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test File',
        '',
        '## shot 1',
        'First shot content',
        '',
        '## shot 2',
        'Second shot content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      -- Test finding shot 1
      local start, finish, header = shots.find_current_shot(bufnr, 3)
      assert.are.equal(3, start)
      assert.are.equal(4, finish)
      assert.are.equal(3, header)
    end)
  end)
end)
```

## Mocking

**Framework:** No explicit mocking library detected (plenary doesn't include mock library)

**Patterns:**
- Lua tables used as test doubles: Create buffer directly with `vim.api.nvim_create_buf(false, true)`
- State passed as function parameters for testability: See `tmux/init.lua` - operations receive detect/send/messages modules
- Pcall guards in test code to handle optional dependencies:
  ```lua
  local ok, oil = pcall(require, 'oil')
  if ok then
    -- test oil functionality
  end
  ```

**What to Mock:**
- External system commands: Use `vim.fn.systemlist()` return values directly in setup
- File operations: Use temp buffers instead of disk (see `shots_spec.lua`)
- Vim API calls: Create buffers and test with actual API

**What NOT to Mock:**
- Internal module functions: Test through public API
- Vim API itself: Use real buffers and cursors in tests
- Table data structures: Use literal tables in tests

## Fixtures and Factories

**Test Data:**
- Literal test data inline in tests (no factory files)
- Buffers created per-test:
  ```lua
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '# Test File',
    '## shot 1',
    'content'
  })
  ```
- Reusable test data patterns:
  - Markdown with shots: title, empty lines, shot headers, content
  - Executed shot headers with timestamps: `'## x shot 1 (2026-01-20 12:00:00)'`
  - Open vs executed shot patterns

**Location:**
- No separate fixture files
- Test data defined inline in `it()` blocks
- Promotes test readability (data close to assertions)

## Coverage

**Requirements:** Not enforced (no coverage configuration found)

**View Coverage:**
- No documented coverage reporting
- Tests are manual and ad-hoc
- Focus is on behavior coverage, not line coverage

## Test Types

**Unit Tests:**
- Most tests: Functions like `find_current_shot()`, `parse_shot_header()`, `get_shot_content()` tested in isolation
- Create minimal test buffers with sample data
- Assert on return values and side effects
- Example: `shots_spec.lua` tests individual shot detection logic

**Integration Tests:**
- Tests verifying module structure: `assert.is_function(analytics.generate_report)` in `analytics_spec.lua`
- Tests checking exported functions exist
- Minimal integration (mostly checking public API surface)

**E2E Tests:**
- Not present in codebase
- Plugin is interactive (Vim commands, keybindings); would require separate system testing

## Common Patterns

**Async Testing:**
- No async patterns detected
- Vim scheduling handled via `utils.defer()` in code, not in tests
- Tests run synchronously with buffer state

**Error Testing:**
```lua
it('returns nil when no shot found', function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local lines = {'# No shots here', 'Just text'}
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  local start, finish, header = shots.find_current_shot(bufnr, 1)
  assert.is_nil(start)
  assert.is_nil(finish)
  assert.is_nil(header)
end)
```

**String/Regex Testing:**
- Used heavily for pattern matching: `assert.is_truthy(result:match('^## x shot 1'))`
- Negative matching: `assert.is_falsy(result:match('2026%-01%-20 12:00:00'))`

**Table Testing:**
- Iterate over test cases and apply assertions:
  ```lua
  local test_cases = {
    { cmd = 'zsh', expected = true },
    { cmd = 'bash', expected = true },
    { cmd = 'nvim', expected = false },
  }
  for _, tc in ipairs(test_cases) do
    assert.are.equal(tc.expected, is_shell_pane(tc.cmd))
  end
  ```

**Property Checking:**
- Validate structure in `project_spec.lua`:
  ```lua
  it('exports expected functions', function()
    assert.is_function(project.has_projects)
    assert.is_function(project.get_projects_dir)
    assert.is_function(project.list_projects)
  end)
  ```
- Ensures module API contract

## Module Structure Testing

Tests verify both behavior and exported API:

**Example from `analytics_spec.lua`:**
```lua
describe('module structure', function()
  it('exports expected functions', function()
    assert.is_function(analytics.generate_report)
    assert.is_function(analytics.show)
    assert.is_function(analytics.show_global)
    assert.is_function(analytics.show_project)
  end)
end)

describe('generate_report', function()
  it('returns a table of lines', function()
    local lines = analytics.generate_report(nil)
    assert.is_table(lines)
    assert.is_true(#lines > 0)
  end)

  it('includes header in report', function()
    local lines = analytics.generate_report(nil)
    assert.is_true(lines[1]:match('# Shooter Analytics') ~= nil)
  end)
end)
```

Combines structural validation with functional testing of report generation.

## Test Scope

Tests focus on:
- **Module-level behavior**: What does the function return?
- **Edge cases**: Empty inputs, nil values, boundary conditions
- **Regex patterns**: Shot header matching ignoring code blocks
- **Table structure**: Correct field names in returned tables
- **Timestamp handling**: Parsing and updating timestamps in headers

Tests avoid:
- System integration (no real tmux testing)
- File I/O to disk (use buffers)
- Command execution
- Neovim autocommands
- Complex workflow scenarios

---

*Testing analysis: 2026-01-30*

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
2. **Context file wiring**: Every repo has `.ai-human-context.md` referenced in context files (CLAUDE.md, GEMINI.md, AGENTS.md)

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

# Lua Conventions

Lua-specific coding standards and best practices.

## Variables and Scope

- Use `local` for all variables by default — global pollution is the top Lua mistake
- Declare variables at the narrowest scope possible
- Use `local` for functions too: `local function foo() end`
- Avoid `_G` modifications except for intentional global registration

## Modules

- Modules return a table of public functions and values
- One module per file
- Use the module pattern:
  ```lua
  local M = {}
  function M.greet(name) return "hello " .. name end
  return M
  ```
- Never use the deprecated `module()` function

## Tables

- Use tables as the primary data structure (arrays, maps, objects)
- Use `#t` for array length only on sequence tables (no gaps)
- Prefer `ipairs` for array iteration, `pairs` for map iteration
- Initialize tables with constructors: `{ x = 1, y = 2 }`

## Strings

- Prefer string methods over patterns when the task is simple
- Use `string.format` for complex string building
- Use `[[long strings]]` for multi-line text
- Be aware: Lua strings are 1-indexed

## Error Handling

- Use `pcall`/`xpcall` for protected calls at boundaries
- Return `nil, error_message` for expected failures (Lua convention)
- Use `error()` for programmer errors (unexpected states)
- Always check return values from functions that can fail

## Performance

- Cache frequently accessed global functions locally: `local insert = table.insert`
- Avoid creating tables in hot loops — reuse when possible
- Use `table.concat` over repeated `..` for string building
- Pre-allocate tables with `table.create(n)` in Luau when size is known (Luau-specific, not standard Lua/LuaJIT)

## Tooling

- Use StyLua for formatting
- Use LuaCheck for linting and static analysis
- Use Busted or LuaUnit for testing
- Specify Lua version (5.1, 5.4, LuaJIT, Luau) in project config

## Style

- Use `snake_case` for variables and functions
- Use `PascalCase` for classes/constructors
- Use `UPPER_SNAKE` for constants
- Two-space or four-space indentation (be consistent within project)
- Prefer early returns to reduce nesting

---

## File Ownership

| File | Owner | AI Can Edit |
|------|-------|-------------|
| `.ai-human-context.md` | Human | **NO** - Human-written context only |
| `.planning/codebase/*` | GSD | **NO** - Auto-generated by `/gsd:map-codebase` |
| `.ai-rules.json` | Both | Yes - Add missing rules as needed |
| `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` | Script | **NO** - Auto-generated by `sync.sh` |

---

## Session Close Protocol

```bash
git status              # Check what changed
git add <files>         # Stage code changes
git commit -m "..."     # Commit code
git push                # Push to remote
```
