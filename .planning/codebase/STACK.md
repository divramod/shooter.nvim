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
