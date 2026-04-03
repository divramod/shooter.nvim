# Codebase Structure

**Analysis Date:** 2026-04-03

## Directory Layout

```
shooter.nvim/
├── lua/shooter/               # Main plugin source (Lua modules)
│   ├── init.lua               # Plugin entry point (setup function)
│   ├── config.lua             # Default config + merge logic
│   ├── commands.lua           # All :Sho* user command registrations
│   ├── keymaps.lua            # Default keymap definitions
│   ├── utils.lua              # Shared utility functions
│   ├── cheatsheet.lua         # Keymap cheatsheet display
│   ├── filter_state.lua       # Global filter state management
│   ├── health.lua             # :checkhealth integration
│   ├── help.lua               # Help display
│   ├── images.lua             # Image insertion logic
│   ├── prd.lua                # PRD integration
│   ├── sound.lua              # Sound feedback on shot send
│   ├── syntax.lua             # Syntax highlighting + autocommands
│   ├── analytics/             # Shot analytics and reporting
│   │   ├── init.lua           # Analytics display (buffer + keymaps)
│   │   ├── data.lua           # Data collection from shotfiles
│   │   ├── report.lua         # Report generation (text tables)
│   │   └── chart.lua          # ASCII chart rendering
│   ├── context/               # Context detection (buffer type awareness)
│   │   ├── init.lua           # Detect current context (telescope/oil/shotfile/buffer)
│   │   └── resolvers.lua      # Context resolution helpers
│   ├── core/                  # Core domain logic
│   │   ├── context.lua        # Global/project context file management
│   │   ├── ext_config.lua     # YAML-based external config (global + project-local)
│   │   ├── files.lua          # Shotfile CRUD, listing, tracking
│   │   ├── greenkeep.lua      # Maintenance/cleanup operations
│   │   ├── move_picker.lua    # Fuzzy folder picker for file moves
│   │   ├── movement.lua       # Move shotfile between folders
│   │   ├── project.lua        # Mono-repo project detection
│   │   ├── rename.lua         # Shotfile rename with renumbering
│   │   ├── renumber.lua       # Shot renumbering within a file
│   │   ├── repos.lua          # Cross-repo shotfile creation
│   │   ├── shot_actions.lua   # High-level shot operations (create, toggle, navigate, yank, extract)
│   │   ├── shot_delete.lua    # Shot deletion
│   │   ├── shot_move.lua      # Move shot between shotfiles
│   │   ├── shot_normalize.lua # Whitespace normalization after shot operations
│   │   ├── shots.lua          # Shot detection, parsing, boundary finding
│   │   └── templates.lua      # Shotfile template rendering
│   ├── dashboard/             # Drill-down dashboard picker
│   │   ├── init.lua           # Three-step picker UI (repos -> files -> shots)
│   │   └── data.lua           # Dashboard data collection
│   ├── health/                # Health check submodule
│   │   └── tools.lua          # Tool availability checks
│   ├── inbox/                 # External inbox import
│   │   ├── init.lua           # Inbox module entry
│   │   └── picker.lua         # Inbox file/task picker
│   ├── keymaps/               # Keymap submodules
│   │   ├── oil.lua            # Oil file browser keymaps
│   │   └── picker.lua         # Telescope picker keymaps
│   ├── providers/             # AI provider abstraction
│   │   ├── init.lua           # Provider registry + detection logic
│   │   ├── claude.lua         # Claude Code provider
│   │   ├── codex.lua          # OpenAI Codex provider
│   │   ├── copilot.lua        # GitHub Copilot provider
│   │   ├── gemini.lua         # Google Gemini provider
│   │   └── opencode.lua       # OpenCode provider
│   ├── queue/                 # Shot queue system
│   │   ├── init.lua           # Queue add/remove/count
│   │   ├── picker.lua         # Queue viewer picker
│   │   └── storage.lua        # Queue JSON persistence
│   ├── session/               # Telescope session state
│   │   ├── init.lua           # Session lifecycle (get/create/switch)
│   │   ├── defaults.lua       # Default session values
│   │   ├── filter.lua         # Filter logic (by folder, status)
│   │   ├── picker.lua         # Session picker UI
│   │   ├── sort.lua           # Sort logic (by name, date, shots)
│   │   └── storage.lua        # Session JSON persistence
│   ├── telescope/             # Telescope picker integration
│   │   ├── pickers.lua        # Main picker definitions (files, shots, repos)
│   │   ├── actions.lua        # Custom telescope actions
│   │   ├── helpers.lua        # Picker helper functions
│   │   ├── picker_help.lua    # In-picker help display
│   │   ├── previewers.lua     # Custom file/shot previewers
│   │   └── toggle_panes_picker.lua  # Tmux pane toggle picker
│   ├── tmux/                  # Tmux integration
│   │   ├── init.lua           # Tmux module entry (delegates to submodules)
│   │   ├── config_panes.lua   # Parse tmux.yml pane config
│   │   ├── create.lua         # Create AI panes
│   │   ├── detect.lua         # Detect tmux environment and AI panes
│   │   ├── hidden_session.lua # Hidden tmux session for toggled-away panes
│   │   ├── keys.lua           # Send-keys mode implementation
│   │   ├── messages.lua       # Build shot messages with context
│   │   ├── operations.lua     # High-level send operations
│   │   ├── panes.lua          # Pane listing and info
│   │   ├── renumber_helper.lua # Pane renumber helper
│   │   ├── script_panes.lua   # Script-based pane operations
│   │   ├── send.lua           # Low-level tmux text sending
│   │   ├── shell.lua          # Shell command execution in panes
│   │   ├── toggle_panes.lua   # Show/hide configured panes
│   │   ├── watch.lua          # Watch pane output
│   │   └── wrapper.lua        # Tmux command wrapper
│   └── tools/                 # Utility tools
│       ├── clipboard_image.lua # Smart paste (detect clipboard images)
│       ├── obsidian.lua       # Open current file in Obsidian
│       ├── response_viewer.lua # View AI responses for sent shots
│       ├── response_viewer/   # Provider-specific response viewers
│       │   ├── claude.lua     # Claude response file parsing
│       │   └── opencode.lua   # OpenCode response file parsing
│       └── token_counter.lua  # Estimate token count for shots
├── after/syntax/              # Neovim after-plugin syntax
│   └── markdown.vim           # Additional markdown syntax rules
├── config/                    # Plugin configuration templates (empty/minimal)
├── doc/                       # Neovim help documentation
│   ├── shooter.txt            # :help shooter documentation
│   └── tags                   # Help tag index
├── docker-compose/            # Docker compose related files
│   ├── AGENTS.md              # Agent instructions for docker context
│   ├── CLAUDE.md              # Claude instructions for docker context
│   ├── GEMINI.md              # Gemini instructions for docker context
│   └── HAL.md                 # HAL instructions for docker context
├── plans/                     # Development plans
│   └── progress.txt           # Progress tracking
├── scripts/                   # External scripts
│   ├── shell/                 # Shell scripts directory
│   └── shooter-clipboard-image # Clipboard image capture script
├── templates/                 # Template files for shotfile/context creation
│   ├── shooter-context-instructions.md
│   ├── shooter-context-instructions-multishot.md
│   ├── shooter-context-message.md
│   ├── shooter-context-project-template.md
│   └── VARIABLES.md           # Template variable documentation
├── tests/                     # Test files (mirroring lua/shooter/ structure)
│   ├── minimal_init.lua       # Minimal Neovim init for testing
│   ├── analytics/             # Analytics tests
│   ├── core/                  # Core module tests
│   ├── dashboard/             # Dashboard tests
│   ├── providers/             # Provider tests
│   ├── queue/                 # Queue tests (implied)
│   ├── session/               # Session tests
│   ├── telescope/             # Telescope tests
│   ├── tmux/                  # Tmux tests
│   └── tools/                 # Tools tests
├── .shooter/                  # Project's own shooter config (dogfooding)
│   └── ai/                    # AI-related project files
│       ├── shotfiles/         # Shotfiles for this project
│       └── ...                # Context, diagrams, research
├── AGENTS.md                  # AI agent instructions
├── CLAUDE.md                  # Claude-specific instructions
├── GEMINI.md                  # Gemini-specific instructions
├── HAL.md                     # HAL tool instructions
├── PROJECT.md                 # Project description
├── README.md                  # User-facing documentation
├── CHANGELOG.md               # Version changelog
└── LICENSE                    # License file
```

## Directory Purposes

**`lua/shooter/`:**
- Purpose: All plugin source code
- Contains: Lua modules organized by domain
- Key files: `init.lua` (entry), `commands.lua` (all commands), `config.lua` (defaults)

**`lua/shooter/core/`:**
- Purpose: Domain logic for shots and shotfiles
- Contains: Shot detection/parsing, file management, movement, renaming, templates, project support
- Key files: `shots.lua` (shot boundary detection), `files.lua` (file CRUD), `shot_actions.lua` (user-facing shot operations), `ext_config.lua` (YAML config system)

**`lua/shooter/tmux/`:**
- Purpose: All tmux interaction - detecting panes, sending text, managing pane layout
- Contains: 15 submodules covering pane detection, text sending, pane creation/toggling
- Key files: `operations.lua` (high-level send flow), `send.lua` (low-level tmux commands), `detect.lua` (pane discovery), `toggle_panes.lua` (show/hide panes)

**`lua/shooter/providers/`:**
- Purpose: AI provider abstraction and detection
- Contains: Provider registry (`init.lua`) and individual provider implementations
- Key files: `init.lua` (registry, TTY-based detection, tmux variable detection)

**`lua/shooter/telescope/`:**
- Purpose: All Telescope picker UIs
- Contains: Picker definitions, custom actions, previewers, helpers
- Key files: `pickers.lua` (main picker functions), `actions.lua` (custom telescope actions)

**`lua/shooter/session/`:**
- Purpose: Persist telescope picker state per repo
- Contains: Session CRUD, filter/sort logic, picker for session switching
- Key files: `init.lua` (session lifecycle), `storage.lua` (JSON persistence)

**`tests/`:**
- Purpose: Unit tests mirroring `lua/shooter/` structure
- Contains: `*_spec.lua` test files
- Key files: `minimal_init.lua` (test harness init)

**`templates/`:**
- Purpose: Markdown templates for new shotfiles and context injection
- Contains: Template files with variable placeholders
- Key files: `shooter-context-message.md` (injected before each shot), `VARIABLES.md` (variable documentation)

## Key File Locations

**Entry Points:**
- `lua/shooter/init.lua`: Plugin setup, called by user's Neovim config
- `lua/shooter/commands.lua`: All `:Sho*` command registrations (~80+ commands)
- `lua/shooter/keymaps.lua`: All default keymap bindings

**Configuration:**
- `lua/shooter/config.lua`: Lua-side defaults and config merge logic
- `lua/shooter/core/ext_config.lua`: YAML-based config system (global + project-local)

**Core Logic:**
- `lua/shooter/core/shots.lua`: Shot detection, parsing, marking as executed
- `lua/shooter/core/files.lua`: Shotfile creation, listing, tracking, git root detection
- `lua/shooter/core/shot_actions.lua`: Create, toggle, navigate, yank, extract shots
- `lua/shooter/tmux/operations.lua`: Orchestrates shot sending to AI panes
- `lua/shooter/tmux/send.lua`: Low-level tmux text transmission
- `lua/shooter/providers/init.lua`: Provider registry and AI process detection

**Testing:**
- `tests/minimal_init.lua`: Test environment bootstrap
- `tests/core/shots_spec.lua`: Shot detection tests
- `tests/core/shot_actions_spec.lua`: Shot action tests
- `tests/tmux/init_spec.lua`: Tmux module tests

## Naming Conventions

**Files:**
- `snake_case.lua` for all Lua modules: `shot_actions.lua`, `ext_config.lua`, `toggle_panes.lua`
- `init.lua` for module entry points (standard Lua/Neovim convention)
- `*_spec.lua` for test files: `shots_spec.lua`, `send_spec.lua`

**Directories:**
- `snake_case` for all directories: `core/`, `tmux/`, `response_viewer/`
- Test directories mirror source directories: `tests/core/`, `tests/tmux/`

**Commands:**
- PascalCase with `Sho` prefix: `:ShoShotSend`, `:ShoShotfileNew`, `:ShoTmuxTogglePanes`
- Namespace grouping: `ShoShotfile*`, `ShoShot*`, `ShoTmux*`, `ShoCfg*`, `ShoTool*`, `ShoAnalytics*`, `ShoNav*`, `ShoRepo*`

## Where to Add New Code

**New AI Provider:**
- Create: `lua/shooter/providers/{name}.lua`
- Register in: `lua/shooter/providers/init.lua` (add to `load_providers()`)
- Follow pattern of `lua/shooter/providers/claude.lua`: export `name`, `display_name`, `process_pattern`, `send_text()`, `send_file_reference()`, `build_shot_message()`, `get_create_command()`

**New User Command:**
- Add to: `lua/shooter/commands.lua` in the appropriate `setup_*_commands()` function
- Add keymap to: `lua/shooter/keymaps.lua` under the matching namespace section
- Use `create_cmd(name, fn, opts, alias)` for optional backward-compat alias
- Use `require_shotfile(fn)` wrapper if the command requires being in a shotfile

**New Core Feature:**
- Create: `lua/shooter/core/{feature}.lua`
- Wire up commands in: `lua/shooter/commands.lua`
- Add tests: `tests/core/{feature}_spec.lua`

**New Tool:**
- Create: `lua/shooter/tools/{tool}.lua`
- Add command in: `lua/shooter/commands.lua` under `setup_tool_commands()`
- Add keymap in: `lua/shooter/keymaps.lua` under `-- TOOLS NAMESPACE (l prefix)`

**New Telescope Picker:**
- Add picker function to: `lua/shooter/telescope/pickers.lua`
- Add custom actions to: `lua/shooter/telescope/actions.lua` if needed
- Add previewer to: `lua/shooter/telescope/previewers.lua` if needed

**New Tmux Submodule:**
- Create: `lua/shooter/tmux/{feature}.lua`
- Wire into: `lua/shooter/tmux/init.lua` if it needs a public API
- Add tests: `tests/tmux/{feature}_spec.lua`

**Shared Utilities:**
- Add to: `lua/shooter/utils.lua` for functions used across multiple modules

## Special Directories

**`.shooter/`:**
- Purpose: Project-specific shooter configuration and AI shotfiles (the plugin dogfoods itself)
- Generated: Partially (created by plugin commands)
- Committed: Yes (shotfiles are version-controlled project artifacts)

**`~/.config/shooter/nvim/`:**
- Purpose: Global user config, sessions, bullets (sent shot copies), filter state
- Generated: Yes (created automatically on first use)
- Committed: No (user-local data)

**`templates/`:**
- Purpose: Plugin-bundled templates for new shotfiles and context injection
- Generated: No
- Committed: Yes (part of plugin distribution)

**`after/syntax/`:**
- Purpose: Additional markdown syntax rules loaded after built-in syntax
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-04-03*
