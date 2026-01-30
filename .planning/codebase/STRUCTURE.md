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
