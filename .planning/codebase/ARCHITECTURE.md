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
