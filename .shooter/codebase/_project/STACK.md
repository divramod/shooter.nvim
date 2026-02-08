# Technology Stack

**Analysis Date:** 2026-02-08

## Languages

**Primary:**
- Lua 5.1+ - Plugin scripting language for Neovim, all core functionality

## Runtime

**Environment:**
- Neovim >= 0.9.0 (required)
  - Uses Neovim's Lua runtime (vim global API)
  - Leverages vim.fn, vim.api, vim.system, vim.notify, vim.json

**No external language runtimes needed** - executes entirely within Neovim

## Frameworks

**Core:**
- Neovim plugin architecture - event handlers, commands, keymaps
  - Uses vim.api.nvim_create_user_command for command registration
  - Uses vim.keymap.set for keybinding management
  - Uses vim.api.nvim_buf_* and vim.api.nvim_win_* for buffer/window manipulation

**UI/Picker:**
- telescope.nvim (required) - file picker, shot picker, queue picker
  - Pickers (`telescope.pickers`)
  - Finders (`telescope.finders`)
  - Previewers (`telescope.previewers`)
  - Actions (`telescope.actions`)

**File Management:**
- oil.nvim (required) - file browser, directory navigation, file operations
  - Enables file move/copy/delete commands in directory view

**Plugin Utilities:**
- plenary.nvim (required, via telescope) - Lua utilities, async operations

**Navigation:**
- vim-i3wm-tmux-navigator (required) - seamless nav between vim splits and tmux panes
  - Provides TmuxNavigateLeft, TmuxNavigateRight, etc. commands

**Optional Plugins:**
- gp.nvim (optional) - voice dictation via GpWhisper command
- (Other Neovim plugins can be referenced but not required)

## External Tools Integration

**Primary:**
- tmux - terminal multiplexer for managing panes and sending text
  - Invoked via `tmux send-keys`, `tmux load-buffer`, `tmux paste-buffer`
  - Version detection via `tmux -V`

- Claude CLI (optional) - AI assistant process
  - Detected via process list matching "claude" pattern
  - Invoked in tmux panes (not called directly)

- OpenCode CLI (optional) - alternative AI assistant
  - Detected via process list matching "opencode" pattern
  - Invoked in tmux panes with `-c` flag for continue mode

**Optional Tools:**
- git - version control
  - Called via `git rev-parse --show-toplevel` to find repo root
  - Used to determine session storage paths

- ttok (Python package) - token counter for Claude models
  - Requires `pip install ttok`
  - Called via stdin: `ttok < file`

- hal CLI - image picker for clipboard images
  - Invoked in tmux: `hal image pick --output <tmpfile>`
  - Used with `<space>I` keymap for image insertion

- gp.nvim voice dictation (requires external whisper setup)
  - Triggered via `:GpWhisper` command
  - Used with `<space>e` keymap

## Key Dependencies

**Critical (builtin Neovim APIs):**
- vim.api.* - Buffer/window/command management
- vim.fn.system / vim.fn.systemlist - subprocess execution
- vim.fn.jobstart / vim.fn.jobwait - async job management
- vim.json.encode / vim.json.decode - JSON serialization
- vim.notify - user notifications
- vim.ui.input - user input prompts

**Configuration & Data:**
- vim.deepcopy - table cloning for config merging
- vim.split - string splitting utilities
- io.popen - command execution (for tool version checks)
- os.getenv - environment variable access (TMUX, TERM_PROGRAM, etc.)
- os.time, os.tmpname - timestamps and temp files
- debug.getinfo - introspection for plugin path detection

## Configuration

**Environment:**
- Configured via `require('shooter').setup(user_config)`
- Defaults in `lua/shooter/config.lua`
- Merged with user config via `vim.tbl_deep_extend`

**Key Config Variables:**
- `paths.global_context` - global context file (default: ~/.config/shooter.nvim/shooter-context-global.md)
- `paths.project_context` - project context relative to git root
- `paths.prompts_root` - shotfiles directory (default: .shooter/shotfiles)
- `paths.queue_file` - queue persistence (default: .shooter/shotfiles/.shot-queue.json)
- `tmux.delay` - send delay between operations (default: 0.2s)
- `tmux.send_mode` - 'paste' (fast) or 'keys' (full history)
- `patterns.shot_header` - regex for shot markers in files
- `features.*` - feature toggles

**Environment Variables Read:**
- `TMUX` - detect if running in tmux session
- `TERM_PROGRAM` - detect terminal type (iTerm)
- `TERM_PROGRAM_VERSION` - terminal version

## Build & Development

**No build step required** - Lua plugin distributed as-is

**Test Framework:**
- busted (Lua test framework)
- Config: minimal_init.lua for isolated test environment
- Test patterns: `tests/**/*_spec.lua`

**Development Tools:**
- Lua linter configuration (if used in CI)

## Data Storage

**Local File Storage:**
- JSON format: Queue persistence at `.shooter/shotfiles/.shot-queue.json`
- YAML format: Session config at `~/.config/shooter.nvim/sessions/<repo>/`
- Plain text: Markdown shotfiles in `.shooter/shotfiles/`
- Images: `.shooter/config/nvim/images/`

**No database** - file-based persistence only

## Platform Requirements

**Development:**
- Neovim >= 0.9.0
- tmux (optional but strongly recommended for send functionality)
- macOS, Linux, or Windows with WSL

**Production (Deployment):**
- Neovim plugin managers (lazy.nvim, packer.nvim, vim-plug)
- Distributed via GitHub: github.com/divramod/shooter.nvim
- No release binaries needed - pure Lua distribution

---

*Stack analysis: 2026-02-08*
