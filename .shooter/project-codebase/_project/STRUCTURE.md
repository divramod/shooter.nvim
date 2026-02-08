# Codebase Structure

**Analysis Date:** 2026-02-08

## Directory Layout

```
shooter.nvim/
├── lua/shooter/                    # Main plugin code (Lua)
│   ├── init.lua                    # Plugin entry point
│   ├── commands.lua                # Command registration (670 lines)
│   ├── config.lua                  # Config defaults & setup
│   ├── keymaps.lua                 # Keymap registration
│   ├── utils.lua                   # Shared utilities
│   ├── syntax.lua                  # Syntax highlighting setup
│   ├── cheatsheet.lua              # Cheatsheet display
│   ├── help.lua                    # Help text
│   ├── health.lua                  # Health check commands
│   ├── sound.lua                   # Audio notifications
│   ├── images.lua                  # Image insertion
│   ├── filter_state.lua            # Filter state tracking
│   ├── prd.lua                     # PRD (Product Requirements) tools
│   ├── inbox/                      # External task inbox
│   │   ├── init.lua
│   │   └── picker.lua
│   ├── keymaps/                    # Namespace-specific keymaps
│   │   ├── oil.lua                 # Oil.nvim buffer keymaps
│   │   └── picker.lua              # Telescope picker keymaps
│   ├── core/                       # Core shot/file management (14 files, 3000+ lines)
│   │   ├── shots.lua               # Shot detection & parsing (241 lines)
│   │   ├── files.lua               # File operations & discovery (243 lines)
│   │   ├── shot_actions.lua        # Shot manipulation (788 lines)
│   │   ├── shot_delete.lua         # Shot deletion
│   │   ├── shot_move.lua           # Move shots between files
│   │   ├── shot_normalize.lua      # Shot normalization
│   │   ├── movement.lua            # File folder movement (257 lines)
│   │   ├── project.lua             # Project detection & selection
│   │   ├── repos.lua               # Multi-repo support
│   │   ├── rename.lua              # File renaming
│   │   ├── renumber.lua            # Shot re-sequencing (212 lines)
│   │   ├── templates.lua           # Template insertion (219 lines)
│   │   ├── context.lua             # Core context utilities
│   │   └── greenkeep.lua           # Date format migration
│   ├── context/                    # Context injection
│   │   ├── init.lua                # Context detection
│   │   └── resolvers.lua           # Context file resolution (204 lines)
│   ├── telescope/                  # Telescope UI integration (5 files, 1200+ lines)
│   │   ├── pickers.lua             # Main pickers (457 lines)
│   │   ├── helpers.lua             # Picker utilities (406 lines)
│   │   ├── actions.lua             # Keymap actions (225 lines)
│   │   ├── previewers.lua          # Preview generators
│   │   ├── toggle_panes_picker.lua # Tmux pane toggle UI (235 lines)
│   │   └── picker_help.lua         # Help text for pickers
│   ├── session/                    # Session/state management (6 files, 1000+ lines)
│   │   ├── init.lua                # Session lifecycle (201 lines)
│   │   ├── storage.lua             # Session persistence (259 lines)
│   │   ├── picker.lua              # Session selection UI (198 lines)
│   │   ├── filter.lua              # Folder filter state
│   │   ├── sort.lua                # Sort order state
│   │   └── defaults.lua            # Default session template
│   ├── tmux/                       # Tmux integration (14 files, 2000+ lines)
│   │   ├── init.lua                # Entry point
│   │   ├── send.lua                # Text transmission (194 lines)
│   │   ├── operations.lua          # Send operations (279 lines)
│   │   ├── detect.lua              # Tmux environment detection
│   │   ├── create.lua              # Session creation (211 lines)
│   │   ├── messages.lua            # Message formatting
│   │   ├── panes.lua               # Pane operations
│   │   ├── shell.lua               # Shell command execution
│   │   ├── keys.lua                # Tmux keybinding helpers
│   │   ├── wrapper.lua             # Tmux command wrappers
│   │   ├── watch.lua               # Watch mode
│   │   ├── toggle_panes.lua        # Pane visibility toggle (388 lines)
│   │   ├── config_panes.lua        # Pane config loading (191 lines)
│   │   ├── hidden_session.lua      # Hidden session management (190 lines)
│   │   ├── script_panes.lua        # Script-driven panes
│   │   └── renumber_helper.lua     # Tmux pane renumbering helper
│   ├── tools/                      # Utility tools (5 files)
│   │   ├── response_viewer.lua     # View AI responses
│   │   ├── response_viewer/        # Provider-specific viewers
│   │   │   ├── claude.lua
│   │   │   └── opencode.lua
│   │   ├── token_counter.lua       # Token counting (ttok wrapper)
│   │   ├── clipboard_image.lua     # Clipboard image handling
│   │   └── obsidian.lua            # Obsidian integration
│   ├── providers/                  # AI provider adapters
│   │   ├── init.lua
│   │   ├── claude.lua              # Claude CLI adapter
│   │   └── opencode.lua            # OpenCode adapter
│   ├── analytics/                  # Usage analytics (4 files)
│   │   ├── init.lua
│   │   ├── data.lua                # Analytics data collection (313 lines)
│   │   ├── report.lua              # Report generation
│   │   └── chart.lua               # Chart rendering
│   ├── dashboard/                  # Dashboard UI (2 files)
│   │   ├── init.lua
│   │   └── data.lua                # Dashboard data (222 lines)
│   └── queue/                      # Shot queue for multi-pane (3 files)
│       ├── init.lua
│       ├── picker.lua              # Queue visualization
│       └── storage.lua             # Queue persistence
├── plugin/                         # Entry point directory (empty)
├── doc/                            # Neovim documentation
│   └── shooter.txt                 # Help documentation
├── templates/                      # Template files for injection
│   ├── shooter-context-global-template.md
│   ├── shooter-context-project-template.md
│   └── shooter-context-message.md
├── tests/                          # Test files (40+ specs)
│   ├── core/
│   │   ├── shots_spec.lua
│   │   ├── shot_actions_spec.lua
│   │   ├── files_spec.lua
│   │   ├── project_spec.lua
│   │   ├── rename_spec.lua
│   │   ├── renumber_spec.lua
│   │   ├── movement_spec.lua
│   │   ├── shot_delete_spec.lua
│   │   ├── templates_spec.lua
│   │   ├── greenkeep_spec.lua
│   │   ├── analytics_spec.lua
│   │   └── sound_spec.lua
│   ├── telescope/
│   ├── tools/
│   ├── providers/
│   ├── tmux/
│   ├── dashboard/
│   └── [other test files]
├── scripts/                        # Utility scripts
├── after/                          # After-load plugin hooks
├── README.md                       # Main documentation
├── REFACTORING_PLAN.md             # Planned refactorings
└── .shooter/                       # Shooter-specific config
    ├── VERSION                     # Current version
    ├── config/nvim/                # Nvim-specific config
    └── shotfiles/                  # Theme shotfiles (ai.md, cli.md, etc.)
```

## Directory Purposes

**lua/shooter/init.lua:**
- Purpose: Plugin entry point
- Contains: Plugin initialization, setup function, config merge logic
- Key functions: `setup()`, `get_config()`, `is_initialized()`

**lua/shooter/commands.lua:**
- Purpose: Centralized command registration and dispatch
- Contains: All Vim command definitions organized by namespace (Shotfile, Shot, Tmux, Tool, Cfg, Analytics, Help)
- Key sections: setup_shotfile_commands(), setup_shot_commands(), setup_tmux_commands(), etc.

**lua/shooter/core/shots.lua:**
- Purpose: Shot detection and parsing
- Contains: Regex-based shot header detection, boundary finding, shot numbering
- Key functions: `find_current_shot()`, `find_all_shots()`, `find_open_shots()`, `parse_shot_header()`

**lua/shooter/core/files.lua:**
- Purpose: File discovery, creation, and path operations
- Contains: Git root detection, filename generation, shooter file identification
- Key functions: `create_file()`, `get_prompt_files()`, `is_shooter_file()`, `get_last_edited_file()`

**lua/shooter/core/shot_actions.lua:**
- Purpose: Shot manipulation (create, delete, toggle state, yank)
- Contains: Insertion point detection, shot extraction, state toggling
- Key functions: `create_new_shot()`, `delete_last_shot()`, `toggle_shot_done()`, `extract_subtask()`

**lua/shooter/telescope/pickers.lua:**
- Purpose: Main Telescope picker implementation
- Contains: File picker, shot picker, queue picker with custom keymaps and refreshers
- Key functions: `list_all_files()`, `list_open_shots()`, `list_all_repos_files()`

**lua/shooter/session/init.lua:**
- Purpose: Session lifecycle and state queries
- Contains: Current session caching, session loading/saving, folder toggle
- Key functions: `get_current_session()`, `load_session()`, `save_current()`, `toggle_folder()`

**lua/shooter/tmux/send.lua:**
- Purpose: Text transmission to tmux panes
- Contains: Escape sequence generation, delay calculation, text preparation
- Key functions: `prepare_escape_sequences()`, `calculate_delay()`, `execute_tmux_command()`

**lua/shooter/tmux/operations.lua:**
- Purpose: High-level tmux send operations
- Contains: Current shot send, all shots send, context injection, message handling
- Key functions: `send_current_shot()`, `send_all_shots()`, `send_specific_shots()`

## Key File Locations

**Entry Points:**
- `lua/shooter/init.lua` - Plugin setup, initialization
- `lua/shooter/commands.lua` - All command dispatch
- `lua/shooter/keymaps.lua` - Keymap registration
- `.shooter/config/nvim/` - Project-specific configuration

**Configuration:**
- `lua/shooter/config.lua` - Config defaults and merge logic
- `~/.config/shooter.nvim/shooter-context-global.md` - Global context (user-owned)
- `.shooter/config/nvim/shooter-context-project.md` - Project context (repo-owned)

**Core Logic:**
- `lua/shooter/core/` - Shot/file management (shots, files, shot_actions, movement, project)
- `lua/shooter/tmux/` - AI pane integration (send, detect, operations)
- `lua/shooter/context/` - Context injection logic

**Persistence:**
- `lua/shooter/session/` - Session storage (filters, sort, vim mode)
- `~/.config/shooter.nvim/sessions/<repo-slug>/` - Session files (JSON)
- `.shooter/session/storage.lua` - Session file I/O
- `.shooter/shotfiles/.shot-queue.json` - Queued shots

**UI/Display:**
- `lua/shooter/telescope/` - Pickers and previews
- `lua/shooter/dashboard/` - Dashboard view
- `lua/shooter/syntax.lua` - Syntax highlighting setup

**Testing:**
- `tests/core/` - Unit tests for core modules
- `tests/telescope/` - Telescope integration tests
- `tests/tmux/` - Tmux integration tests

## Naming Conventions

**Files:**
- `init.lua` - Module entry point / exports
- `<name>.lua` - Standalone module
- `<name>_spec.lua` - Test file for `<name>.lua`
- Files in `.shooter/shotfiles/` follow date-title pattern: `YYYYMMDD_HHMM_feature-name.md`

**Directories:**
- Lowercase, snake_case: `telescope`, `session`, `shot_actions`
- One concern per directory (cohesion)
- Submodules grouped by feature area

**Functions:**
- `local function private_helper()` - Private to module (not exported)
- `function M.public_function()` - Exported from module
- `function M.setup()` - Initialization function (naming convention)
- Naming: verb_noun pattern: `find_current_shot()`, `toggle_folder()`, `send_current_shot()`

**Variables:**
- Locals: snake_case (`local shot_start`, `local bufnr`)
- Constants: UPPERCASE_SNAKE_CASE (used rarely, usually in config)
- Module tables: `M = {}` (standard Lua pattern)
- State: Prefix with underscore for internal state (`_current_session`, `_initialized`)

**Types:**
- No explicit type annotations in code (Lua)
- Inline comments document expected types: `---@param bufnr number Buffer handle` (LuaLS format)
- Tests use `_spec.lua` suffix (Busted convention)

## Where to Add New Code

**New Feature (Shot/File Management):**
- Primary code: `lua/shooter/core/<feature>.lua` (e.g., `shot_validation.lua`)
- Tests: `tests/core/<feature>_spec.lua`
- Integration: Register new command in `lua/shooter/commands.lua` if user-facing
- If Telescope UI needed: Add picker/action in `lua/shooter/telescope/`

**New Picker/UI Component:**
- Implementation: `lua/shooter/telescope/pickers.lua` or new file `lua/shooter/telescope/<name>.lua`
- Tests: `tests/telescope/<name>_spec.lua`
- Keymaps: Register in picker's `attach_mappings()` callback
- Help: Add entry to `lua/shooter/telescope/picker_help.lua`

**New Tmux Operation:**
- Implementation: `lua/shooter/tmux/operations.lua` or new submodule
- Low-level tmux: `lua/shooter/tmux/send.lua` or `wrapper.lua`
- Tests: `tests/tmux/<name>_spec.lua`
- Command dispatch: Register in `lua/shooter/commands.lua` (setup_tmux_commands)

**Utilities & Helpers:**
- Shared helpers: `lua/shooter/utils.lua`
- Module-specific: Keep in module file (e.g., `session/filter.lua` for session filtering)
- Don't create new files for single functions—add to existing module or utils

**Configuration & Settings:**
- New config option: Add to `M.defaults` table in `lua/shooter/config.lua`
- User-configurable: Update defaults, document in README.md
- Per-session state: Add to session structure in `lua/shooter/session/defaults.lua`

## Special Directories

**lua/shooter/:**
- Purpose: Main plugin code
- Generated: No
- Committed: Yes (all source code)

**tests/:**
- Purpose: Test suites (unit + integration)
- Generated: No
- Committed: Yes
- Run with: `busted` or `nvim --noplugin -u scripts/minimal_init.vim -c "PlenaryBustedDirectory tests/"`

**templates/:**
- Purpose: Template files for context injection
- Generated: No
- Committed: Yes
- Used by: Context injection system to scaffold new context files

**.shooter/shotfiles/:**
- Purpose: Theme-based shotfiles (ai.md, cli.md, etc.)
- Generated: Partially (auto-created from .shooter/themes.json if missing)
- Committed: Yes
- Template location: `templates/` directory

**~/.config/shooter.nvim/:**
- Purpose: User global configuration and context
- Generated: Auto-created if missing
- Committed: No (user-specific)
- Contents: `shooter-context-global.md`, plugin config overrides

**.shooter/session/:**
- Purpose: Session storage (filter state, sort order, vim mode per repo)
- Generated: Yes (auto-created, JSON files)
- Committed: No (user-specific state)
- Format: `.shooter/session/config/<repo-slug>/<session-name>.json`

**.shooter/shotfiles/.shot-queue.json:**
- Purpose: Queued shots for multi-pane execution
- Generated: Yes (created by queue operations)
- Committed: No (temporary state)
- Format: JSON array of shot references

---

*Structure analysis: 2026-02-08*
