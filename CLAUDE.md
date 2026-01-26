# Shooter.nvim Architecture

This document describes the internal architecture and design decisions for shooter.nvim.

## Overview

Shooter.nvim is a Neovim plugin for managing iterative development workflows using a shot-based approach. It was refactored from divramod's dotfiles next-action workflow into a standalone, publishable plugin.

## Critical Constraints

- **200-line maximum per file**: Enforces single responsibility and modularity
- **100% functionality preservation**: All features from original implementation maintained
- **Plenary.nvim tests**: All modules have corresponding test files
- **Zero auto-initialization**: Plugin only activates when `setup()` is called

## Directory Structure

```
shooter.nvim/
├── lua/shooter/
│   ├── init.lua              # Main entry point, setup()
│   ├── config.lua            # Configuration defaults
│   ├── utils.lua             # Shared utilities
│   ├── commands.lua          # Vim command registration (8 namespaces)
│   ├── keymaps.lua           # Default keybindings (8 namespaces)
│   ├── health.lua            # :checkhealth integration
│   ├── context/              # Context detection for commands
│   │   ├── init.lua          # is_telescope_picker(), is_oil_buffer(), etc.
│   │   └── resolvers.lua     # resolve_shot_target(), resolve_shotfile_target()
│   ├── keymaps/              # Context-specific keymaps
│   │   ├── picker.lua        # Shared telescope picker keymaps
│   │   └── oil.lua           # Oil buffer keymaps (autocmd-based)
│   ├── core/
│   │   ├── files.lua         # File operations
│   │   ├── shots.lua         # Shot detection/marking
│   │   ├── movement.lua      # File movement
│   │   ├── project.lua       # Project detection and paths
│   │   └── context.lua       # Context file management
│   ├── telescope/
│   │   ├── pickers.lua       # Picker constructors
│   │   ├── actions.lua       # Action handlers
│   │   ├── previewers.lua    # Custom previewers
│   │   ├── helpers.lua       # Picker utilities
│   │   └── picker_help.lua   # Picker help popups
│   ├── tmux/
│   │   ├── send.lua          # Send to panes
│   │   ├── detect.lua        # Find Claude panes
│   │   ├── wrapper.lua       # Tmux wrapper commands
│   │   ├── panes.lua         # Pane toggle functionality
│   │   ├── watch.lua         # Watch pane management
│   │   └── messages.lua      # Build messages
│   ├── queue/
│   │   ├── init.lua          # Queue management
│   │   ├── storage.lua       # JSON persistence
│   │   └── picker.lua        # Queue picker
│   ├── dashboard/
│   │   ├── init.lua          # Dashboard main entry
│   │   ├── data.lua          # Gather files and shots
│   │   └── tree.lua          # NuiTree rendering
│   └── session/
│       ├── init.lua          # Session lifecycle management
│       ├── defaults.lua      # DEFAULT template, validation
│       ├── storage.lua       # YAML I/O, session CRUD
│       ├── filter.lua        # Whitelist folder/project filtering
│       ├── sort.lua          # Multi-criteria sorting
│       └── picker.lua        # Telescope pickers for sessions
├── templates/
│   ├── shooter-context-project-template.md
│   └── shooter-context-message.md
├── plugin/
│   └── shooter.lua           # Auto-load bootstrap
├── tests/
│   ├── minimal_init.lua      # Test environment
│   └── [module]_spec.lua     # Test files
└── doc/
    └── shooter.txt           # Vim help docs
```

## Module Breakdown

### Core Modules (`lua/shooter/core/`)

#### files.lua (< 200 lines)
**Responsibilities:**
- Create new shooter files with timestamped names
- Find git root directory
- List shooter files in directory
- Get current file path (normal buffer or Oil)
- Generate slugified filenames

**Key Functions:**
- `create_file(title, folder, content)` - Create new shooter file
- `get_current_file_path()` - Get path of current buffer or Oil cursor
- `find_git_root()` - Locate git repository root
- `get_prompt_files()` - List all .md files in prompts folder
- `generate_filename(title)` - Create timestamped filename

#### shots.lua (< 200 lines)
**Responsibilities:**
- Detect shot boundaries in buffer
- Find current shot at cursor
- Mark shot as executed (add 'x' and timestamp)
- Find all open shots in file
- Parse shot headers

**Key Functions:**
- `find_current_shot(bufnr, cursor_line)` - Get shot at cursor
- `find_all_shots(bufnr)` - Parse all shots in buffer
- `find_open_shots(bufnr)` - Get unexecuted shots only
- `mark_shot_executed(bufnr, shot_line)` - Add 'x' and timestamp
- `parse_shot_header(line)` - Extract shot number
- `get_shot_content(bufnr, start, end)` - Get shot text

#### movement.lua (< 200 lines)
**Responsibilities:**
- Move files between folders (archive/backlog/done/etc.)
- Handle both normal buffers and Oil
- Position cursor after move

**Key Functions:**
- `move_to_folder(target_folder, open_in_oil)` - Generic move
- `move_to_archive()`, `move_to_backlog()`, etc. - Convenience wrappers
- `move_to_git_root()` - Move to repository root

#### context.lua (< 200 lines)
**Responsibilities:**
- Manage context file paths
- Read general and project context files
- Create project context from template
- Build context sections for messages

**Key Functions:**
- `get_global_context_path()` - Return global context path
- `get_project_context_path()` - Return project context path (at git root)
- `read_context_file(path)` - Safe read with fallback
- `get_or_create_project_context()` - Create from template if missing
- `build_context_section()` - Format context for message injection

### Telescope Modules (`lua/shooter/telescope/`)

#### pickers.lua (< 200 lines)
**Responsibilities:**
- Create telescope pickers for files, shots
- Configure layouts and sorting

**Key Functions:**
- `list_all_files(opts)` - Picker for all shooter files
- `list_open_shots(opts)` - Picker for open shots with preview
- `setup_picker(title, items, opts)` - Generic picker builder

#### actions.lua (< 200 lines)
**Responsibilities:**
- Handle telescope selection actions
- Send shots when pressing 1-4
- Multi-select support

**Key Functions:**
- `send_shot(pane_num, entry)` - Send selected shot to pane
- `send_multiple_shots(pane_num)` - Send multi-select
- `edit_file()` - Open selected file
- `delete_file()` - Delete selected file
- `move_file(folder)` - Move to folder

#### previewers.lua (< 200 lines)
**Responsibilities:**
- Custom preview for shot content
- File content preview

**Key Functions:**
- `shot_previewer()` - Show shot content in preview
- `file_previewer()` - Show file content
- `prd_task_previewer()` - Show PRD task details

### Tmux Modules (`lua/shooter/tmux/`)

#### detect.lua (< 200 lines)
**Responsibilities:**
- Find tmux panes running Claude
- Validate tmux is installed

**Key Functions:**
- `find_claude_pane(pane_num)` - Find specific Claude pane
- `list_all_panes()` - Get all tmux panes
- `check_tmux_installed()` - Validate tmux exists
- `check_claude_running()` - Validate Claude process

#### create.lua (< 200 lines)
**Responsibilities:**
- Auto-create tmux panes with Claude
- Wait for Claude to be ready

**Key Functions:**
- `create_claude_pane()` - Create new pane to the left and start Claude
- `wait_for_claude(pane_id, timeout)` - Wait for Claude process to start
- `find_or_create_claude_pane(pane_index)` - Find existing or create new pane

#### send.lua (< 200 lines)
**Responsibilities:**
- Send text to tmux panes
- Handle escape sequences
- Manage timing and delays

**Key Functions:**
- `send_to_pane(pane_id, text, delay)` - Core send function
- `execute_tmux_command(cmd)` - Run tmux command
- `calculate_delay(text)` - Determine delay based on text length

#### messages.lua (< 200 lines)
**Responsibilities:**
- Build single shot messages
- Build multi-shot messages
- Include context sections

**Key Functions:**
- `build_shot_message(bufnr, shot)` - Single shot with context
- `build_multishot_message(bufnr, shots)` - Multiple shots
- `format_shot_content(shot)` - Format shot for sending

### Queue Module (`lua/shooter/queue/`)

#### storage.lua (< 200 lines)
**Responsibilities:**
- Save/load queue as JSON
- Handle file I/O errors

**Key Functions:**
- `save_queue(queue)` - Write to JSON file
- `load_queue()` - Read from JSON file
- `get_queue_file_path()` - Return queue file location

#### init.lua (< 200 lines)
**Responsibilities:**
- Add shots to queue
- Remove from queue
- Clear queue

**Key Functions:**
- `add_to_queue(shot, pane_num)` - Queue shot for later
- `remove_from_queue(index)` - Remove by index
- `clear_queue()` - Delete all queued shots
- `get_queue()` - Retrieve current queue

#### picker.lua (< 200 lines)
**Responsibilities:**
- Telescope picker for queue
- Send/remove actions

**Key Functions:**
- `show_queue_picker()` - Display queue in telescope
- `setup_queue_actions()` - Configure send/remove keybindings

### Dashboard Module (`lua/shooter/dashboard/`)

#### data.lua (< 200 lines)
**Responsibilities:**
- Gather files and their open shots from repos
- Parse shot content and previews
- Support multiple repos from config

**Key Functions:**
- `get_open_shots(filepath)` - Parse file for open shots
- `get_file_title(filepath)` - Extract title from first # heading
- `get_repo_files(repo_path)` - Get all files with open shots
- `get_all_repos()` - Get all configured repos with files
- `get_current_repo()` - Get current repo only

#### tree.lua (< 200 lines)
**Responsibilities:**
- Build NuiTree nodes from repo data
- Render nodes with icons and styling
- Handle node actions (open file/shot)

**Key Functions:**
- `build_nodes(repos)` - Create tree structure from data
- `prepare_node(node)` - Render single node with icons
- `create_tree(winid, nodes)` - Initialize NuiTree
- `get_node_action(node)` - Determine action for Enter key

#### init.lua (< 200 lines)
**Responsibilities:**
- Main dashboard UI with NuiPopup
- Keyboard navigation and actions
- Expand/collapse functionality

**Key Functions:**
- `open()` - Open dashboard popup
- `close()` - Close dashboard
- `refresh()` - Reload dashboard data
- `toggle()` - Toggle dashboard visibility

### Session Module (`lua/shooter/session/`)

Per-repo YAML session management with whitelist-based filtering.

#### defaults.lua (< 100 lines)
**Responsibilities:**
- Define DEFAULT session structure
- Session creation and validation

**Key Functions:**
- `M.DEFAULT` - Default session template
- `create_session(name)` - Create session with name
- `validate_session(session)` - Fill missing keys
- `reset_folders()` - Return default folder config

#### storage.lua (< 200 lines)
**Responsibilities:**
- YAML serialization/deserialization
- Session file I/O operations
- Path resolution for session directories

**Key Functions:**
- `get_repo_slug(git_root)` - Sanitized repo identifier
- `get_sessions_dir(repo_slug)` - Path to sessions folder
- `read_session(repo_slug, name)` - Parse YAML
- `write_session(repo_slug, session)` - Serialize YAML
- `list_sessions(repo_slug)` - Array of session names
- `delete_session(repo_slug, name)` - Remove file
- `rename_session(repo_slug, old, new)` - Rename file

#### init.lua (< 200 lines)
**Responsibilities:**
- Session lifecycle management
- Current session state tracking
- Auto-save on changes

**Key Functions:**
- `get_current_session()` - Load or create init session
- `load_session(name)` - Load specific session
- `save_current()` - Write current to storage
- `toggle_folder(folder)` - Toggle + auto-save
- `set_projects(root, subs)` - Set project filter
- `create_new_session(name)` - New with DEFAULT
- `delete_current_session()` - Delete + load init
- `rename_current_session(new_name)` - Rename file

#### filter.lua (< 150 lines)
**Responsibilities:**
- Apply whitelist folder filtering
- Apply project filtering (root + subprojects)
- Detect file folder/project from path

**Key Functions:**
- `apply_filters(files, session, git_root)` - Main entry
- `detect_file_folder(filepath)` - Extract folder name
- `detect_file_project(filepath, git_root)` - Extract project name
- `get_filter_status(session)` - Status string for title

#### sort.lua (< 150 lines)
**Responsibilities:**
- Multi-criteria sorting with priorities
- File metadata extraction
- Comparator building

**Key Functions:**
- `sort_files(files, session)` - Sort by session config
- `get_enabled_criteria(sort_config)` - Sorted by priority
- `build_comparator(criteria)` - Multi-criteria comparator
- `get_file_metadata(filepath)` - mtime, ctime, shotcount

#### picker.lua (< 200 lines)
**Responsibilities:**
- Telescope pickers for session/project/sort
- Session management UI

**Key Functions:**
- `show_session_picker(callback)` - Load sessions
- `show_new_session_prompt(callback)` - Name input
- `show_project_picker(callback)` - Multi-select with r=root
- `show_sort_picker(callback)` - Configure sort criteria

### Top-Level Modules

#### init.lua (< 200 lines)
**Responsibilities:**
- Main `setup()` function
- Merge user config with defaults
- Initialize all modules

**Key Functions:**
- `setup(user_config)` - Plugin entry point
- Registers all commands
- Sets up keymaps if enabled

#### config.lua (< 200 lines)
**Responsibilities:**
- Default configuration values
- Path definitions
- Configuration merging

**Structure:**
```lua
M.defaults = {
  paths = { ... },
  tmux = { ... },
  telescope = { ... },
  keymaps = { ... },
}
```

#### commands.lua (< 200 lines)
**Responsibilities:**
- Register all vim commands
- Wire to module functions

**Commands:**
- 40+ commands total
- Naming: `Shooter*` (e.g., `ShooterCreate`, `ShooterSend1`)

#### keymaps.lua (< 200 lines)
**Responsibilities:**
- Set up default keybindings
- Respect config.keymaps.enabled

**Keybindings:**
- All use `<space>` prefix (configurable)
- Move commands: `<space>m{a|b|d|...}`
- Send commands: `<space>1-4`
- Queue commands: `<space>q1-4`

#### utils.lua (< 200 lines)
**Responsibilities:**
- Shared helper functions
- File I/O wrappers
- Path manipulation

**Key Functions:**
- `echo(msg)`, `read_file(path)`, `write_file(path, content)`
- `get_timestamp()`, `get_date()`
- `expand_path(path)`, `file_exists(path)`, `ensure_dir(path)`

#### health.lua (< 200 lines)
**Responsibilities:**
- `:checkhealth shooter` integration
- Validate dependencies

**Checks:**
- Telescope installed
- oil.nvim installed
- vim-i3wm-tmux-navigator installed
- Tmux installed
- Claude process running
- Context files exist
- Prompts directory structure

## Context File Migration

### Old Paths
- General: `~/dev/.ai/na-context-general.md`
- Project template: `~/dev/.ai/na-context-project-template.md`
- Project: `.ai/na-context.md` (at git root)

### New Paths
- General: `~/.config/shooter.nvim/shooter-context-global.md`
- Project template: `templates/shooter-context-project-template.md` (in plugin)
- Project: `.shooter.nvim/shooter-context-project.md` (at git root)

## Design Decisions

### 1. Modular Architecture
- Strict 200-line limit enforces single responsibility
- Each module has a clear, focused purpose
- Easy to test in isolation

### 2. Lazy Loading
- Plugin only loads when commands/keys are used
- No auto-initialization on startup
- Modules are require()'d on demand

### 3. Configuration First
- All paths, delays, patterns are configurable
- User config deep-merged with defaults
- No hardcoded values

### 4. Telescope Integration
- Industry-standard picker framework
- Custom actions and previewers
- Consistent UX across all pickers

### 5. Context Injection
- Automatic general + project context
- Template-based message building
- Supports custom templates

### 6. Health Checks
- Built-in dependency validation
- Clear error messages with remediation
- Follows vim.health API

## Context-Aware Command Architecture

**CRITICAL PRINCIPLE:** All commands within a namespace must work identically
across all contexts where that namespace applies.

### Command Namespaces (8 total)

| # | Namespace | Prefix | Description |
|---|-----------|--------|-------------|
| 1 | **Shotfile** | `f` | File-level: create, list, rename, delete, move, history |
| 2 | **Shot** | `s` | Shot-level: new, delete, toggle, move, nav, send, queue |
| 3 | **Tmux** | `t` | All tmux: wrapper commands + pane toggle |
| 4 | **Subproject** | `p` | Subproject management: create, list, ensure-folders |
| 5 | **Tools** | `l` | Utilities: token-counter, obsidian, images, PRD |
| 6 | **Cfg** | `c` | Configuration: shotfile picker, shot picker, plugin |
| 7 | **Analytics** | `a` | Stats: project, global |
| 8 | **Help** | `h` | Info: help, health, dashboard |

### Context Types

Commands detect their current context and resolve targets accordingly:

| Context | Detection | Example |
|---------|-----------|---------|
| `telescope` | `is_telescope_picker()` | Shot picker, shotfile picker |
| `oil` | `is_oil_buffer()` | Oil file browser |
| `shotfile` | `is_in_shotfile()` | Editing a shotfile buffer |
| `buffer` | Default | Any other buffer |

### Namespace Context Mapping

| Namespace | Applicable Contexts |
|-----------|---------------------|
| Shot | shotfile buffer, shot picker |
| Shotfile | shotfile buffer, shotfile picker, Oil |
| Subproject | project file, project picker, Oil (projects/) |

### Key Modules

```
lua/shooter/context/
├── init.lua         # Context detection: is_telescope_picker(), is_oil_buffer(), etc.
└── resolvers.lua    # Target resolution: resolve_shot_target(), resolve_shotfile_target()

lua/shooter/keymaps/
├── picker.lua       # Shared keymap definitions for telescope pickers
└── oil.lua          # Oil buffer keymap bindings (autocmd-based)
```

### Target Resolution Pattern

Every context-aware command should use a resolver:

```lua
-- Example: resolve shotfile target across all contexts
function resolve_shotfile_target()
  local ctx = context.detect_context()

  -- Context 1: In telescope picker
  if ctx == 'telescope' then
    local sel = context.get_telescope_selection()
    if sel and sel.path then return { path = sel.path } end
  end

  -- Context 2: In Oil buffer
  if ctx == 'oil' then
    local entry = context.get_oil_cursor_entry()
    if entry then return { path = entry.path } end
  end

  -- Context 3: In shotfile buffer itself
  if ctx == 'shotfile' then
    return { path = vim.api.nvim_buf_get_name(0) }
  end

  return nil
end
```

### Same Keymap, Same Behavior

The same keymap works identically in all applicable contexts:

```
<space>fr (rename)
- In shotfile buffer → renames current file
- In shotfile picker → renames selected file
- In Oil buffer → renames file under cursor

<space>s. (toggle done)
- In shotfile buffer → toggles shot under cursor
- In shot picker → toggles selected shot
```

### Adding New Commands

When adding a new command:

1. **Identify namespace**: Which namespace does this command belong to?
2. **List contexts**: In which contexts should this command work?
3. **Implement resolver**: Use `resolve_<namespace>_target()` pattern
4. **Bind keymaps**: Add keymap in ALL applicable contexts:
   - Normal mode (`keymaps.lua`)
   - Telescope pickers (`attach_mappings` in pickers.lua)
   - Oil buffers (`keymaps/oil.lua`)
5. **Test**: Verify command works identically in each context

### Bidirectional Aliases

Some commands have bidirectional aliases for discoverability:

```lua
ShooterCfgShot = ShooterShotCfg        -- Both work
ShooterCfgShotfile = ShooterShotfileCfg
```

### Backward Compatibility

All old command names work as aliases:
- `ShooterCreate` → `ShooterShotfileNew`
- `ShooterSend1` → `ShooterShotSend1`
- `ShooterArchive` → `ShooterShotfileMoveArchive`
- etc.

## Testing Strategy

### Test Structure
- Each module has `*_spec.lua` in tests/
- Uses plenary.nvim test framework
- Mock dependencies for isolation

### Test Coverage Goals
- Unit tests for each function
- Integration tests for workflows
- Edge case handling
- Target: 100% code coverage

### Running Tests
```bash
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

## Installation Compatibility

Works with all major plugin managers:
- lazy.nvim (primary)
- packer.nvim
- vim-plug
- Manual (symlink or runtimepath)

## Migration from Dotfiles

For users migrating from divramod's dotfiles:

1. **Install shooter.nvim** via plugin manager
2. **Migrate context files**:
   ```bash
   mkdir -p ~/.config/shooter.nvim
   cp ~/dev/.ai/na-context-general.md ~/.config/shooter.nvim/shooter-context-global.md
   ```
3. **Update project contexts**:
   ```bash
   # In each project
   mkdir -p .shooter.nvim
   mv .ai/na-context.md .shooter.nvim/shooter-context-project.md
   ```
4. **Remove old files** from dotfiles:
   ```bash
   rm lua/functions/next-action.lua
   rm lua/functions/tmux-send.lua
   rm lua/functions/shot-queue.lua
   ```
5. **Update nvim config** to use shooter.nvim

## Performance Considerations

- Lazy loading prevents startup overhead
- File operations are async where possible
- Telescope caching for large file lists
- Minimal dependencies

## Future Enhancements

Potential additions (not in scope for v1.0):
- Treesitter integration for shot parsing
- LSP integration for code context
- Git integration (auto-commit shots)
- Web UI for shot management
- Multi-project queue
- Shot templates
- Shot dependencies/ordering

## Contributing

When adding features:
1. Keep modules under 200 lines
2. Add corresponding tests
3. **Update README.md** when adding or changing features
4. Update this CLAUDE.md if architecture changes
5. Follow existing patterns
6. Don't break backward compatibility

### Documentation Requirements

**Always update README.md when:**
- Adding new commands or keybindings
- Adding new configuration options
- Changing template variables
- Adding new features or workflows
- Fixing behavior that affects user expectations

The README is the primary user-facing documentation. Keep it in sync with code changes.

## Version History

- v1.0.0 (2026-01-21): Initial release, refactored from dotfiles
