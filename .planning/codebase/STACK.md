# Technology Stack

**Analysis Date:** 2026-04-03

## Languages

**Primary:**
- Lua 5.1 (LuaJIT) - All plugin source code (`lua/shooter/`) and tests (`tests/`)

**Secondary:**
- Bash - Scripts for clipboard image handling (`scripts/shooter-clipboard-image`) and shell utilities (`scripts/shell/`)
- Vim script - Syntax highlighting for markdown shot files (`after/syntax/markdown.vim`)
- AppleScript - Used within bash scripts for clipboard image detection via `osascript`

## Runtime

**Environment:**
- Neovim (0.9+ assumed based on `vim.health` API usage)
- Runs inside Neovim's embedded LuaJIT runtime
- Requires tmux for core send-to-pane functionality

**Package Manager:**
- No Lua package manager; distributed as a Neovim plugin via standard plugin managers (lazy.nvim, packer, etc.)
- No lockfile

## Frameworks

**Core:**
- Neovim plugin API (`vim.api`, `vim.fn`, `vim.cmd`) - All UI and editor interaction
- Telescope.nvim - Picker UI for shots, sessions, toggle panes (`lua/shooter/telescope/`)

**Testing:**
- Plenary.nvim - Test runner and assertion library (`tests/minimal_init.lua`)
- Tests use `plenary.busted` style (`describe`/`it` blocks)

**Build/Dev:**
- No build step; pure Lua source loaded directly by Neovim
- Vimdoc for help documentation (`doc/shooter.txt`)

## Key Dependencies

**Required Neovim Plugins:**
- telescope.nvim - Picker UI for shot selection, session management, pane toggling
- oil.nvim - File management and movement commands (`lua/shooter/keymaps/oil.lua`)
- vim-i3wm-tmux-navigator - Seamless navigation between vim splits and tmux panes

**Optional Neovim Plugins:**
- gp.nvim - Voice dictation via `GpWhisper` command

**Required System Tools:**
- tmux - Core dependency for sending shots to AI agent panes
- git - Repository detection, shot file management

**Optional System Tools:**
- ttok (Python pip package) - Token counting for files (`lua/shooter/tools/token_counter.lua`)
- hal CLI - Image picking functionality
- python3 - Required for ttok
- afplay (macOS) - Sound playback on shot send (`lua/shooter/sound.lua`)
- osascript (macOS) - Clipboard image detection (`scripts/shooter-clipboard-image`)
- xdg-open / open - Opening files in Obsidian (`lua/shooter/tools/obsidian.lua`)

## Configuration

**Environment:**
- `.envrc` present at repo root (direnv support)
- `.env.template.worktree` present for worktree environment setup
- No environment variables required for the plugin itself; AI providers are configured externally

**Plugin Configuration:**
- `lua/shooter/config.lua` - Central configuration with `M.defaults` table
- User config merged via `require('shooter').setup(user_config)` in `lua/shooter/init.lua`
- Global context file: `~/.config/hal/util/shooter/nvim/shooter-context-global.md`
- Project context file: `.hal/util/shooter/config/nvim/shooter-context-project.md` (relative to git root)
- Session storage: `~/.config/hal/util/shooter/nvim/sessions/<repo>/` (`lua/shooter/session/storage.lua`)

**Key Config Paths:**
- Shot files (prompts): `.hal/util/shooter/ai/shotfiles/` (relative to project root)
- Queue file: `.hal/util/shooter/ai/shotfiles/.shot-queue.json`
- Clipboard images: `<git-root>/.hal/util/shooter/config/nvim/images/`
- Templates: `templates/` directory within the plugin installation

## Platform Requirements

**Development:**
- Neovim 0.9+
- tmux
- macOS preferred (clipboard image detection uses `osascript`, sound uses `afplay`)
- Linux supported with reduced functionality (xdg-open for Obsidian, no clipboard image detection)

**Production (User Installation):**
- Same as development; plugin is used directly from source
- No compilation or build artifacts
- Standard Neovim plugin installation via any plugin manager

---

*Stack analysis: 2026-04-03*
