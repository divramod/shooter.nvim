# External Integrations

**Analysis Date:** 2026-02-08

## APIs & External Services

**AI Assistant Providers:**
- Claude CLI - AI assistant for processing shots
  - Process detection: `ps aux | grep '[c]laude'`
  - Communication: tmux pane-based (not direct API)
  - Auto-create: supports `claude` command to start new session
  - File references: `@filepath` syntax for Claude Code context

- OpenCode CLI - alternative AI assistant (Gemini-based)
  - Process detection: `ps aux | grep '[o]pencode'`
  - Communication: tmux pane-based (not direct API)
  - Auto-create: supports `opencode -c` command for continue mode
  - File references: `@filepath` with Escape to dismiss autocomplete before Enter

**Provider Registry:**
- Location: `lua/shooter/providers/`
- Implementation: `lua/shooter/providers/init.lua`
- Providers: `claude.lua`, `opencode.lua`
- Detection: Auto-detects running AI process via TTY matching

## External Tools Integration

**Terminal Multiplexing:**
- tmux - primary integration point
  - Commands used:
    - `tmux send-keys` - send keystrokes to pane
    - `tmux load-buffer` / `tmux paste-buffer` - paste text with bracketed paste mode
    - `tmux display-message` - query pane properties
    - `tmux split-window` - create new panes for AI processes
    - `tmux wait-for` - synchronization primitive
  - Config: See `lua/shooter/tmux/` modules
  - Error handling: Commands silently fail (no terminal bleed into editor)

**Version Control:**
- git
  - Used for: repo root detection, remote info extraction
  - Calls: `git rev-parse --show-toplevel`, `git config` for remote URL parsing
  - Files involved: `lua/shooter/core/files.lua`, `lua/shooter/tools/clipboard_image.lua`

**Optional Text Processing Tools:**
- ttok (Python) - token counter for Claude API usage estimation
  - Installation: `pip install ttok`
  - Call: `echo "text" | ttok`
  - Command path: checked via `vim.fn.executable('ttok')`
  - Returns: token count as integer
  - Used in: `lua/shooter/tools/token_counter.lua`
  - Health check: `lua/shooter/health/tools.lua`

**Optional Image Tools:**
- hal CLI - image picking and selection
  - Call: `hal image pick --output <tmpfile>`
  - Used by: `<space>I` keymap for clipboard-based image insertion
  - Integration: `lua/shooter/tools/clipboard_image.lua`, `lua/shooter/images.lua`
  - Health check: `lua/shooter/health/tools.lua`

**Neovim Plugin Integrations:**
- gp.nvim (optional) - voice dictation
  - Command: `:GpWhisper`
  - Used by: `<space>e` keymap for voice input
  - Detection: `vim.fn.exists(':GpWhisper') == 2`
  - Health check: `lua/shooter/health.lua`

## Data Storage & Persistence

**Local File Storage:**
- Queue JSON: `.shooter/shotfiles/.shot-queue.json`
  - Format: JSON array of shot objects
  - Contains: file path, shot number, pane number, timestamp
  - I/O: `lua/shooter/queue/storage.lua` (load_queue, save_queue)

- Session YAML: `~/.config/shooter.nvim/sessions/<repo>/`
  - Format: YAML (custom parser, not external library)
  - Contains: filter state, sort config, picker mode, layout
  - I/O: `lua/shooter/session/storage.lua` (serialize_yaml, parse_yaml)

- Context Files (markdown)
  - Global: `~/.config/shooter.nvim/shooter-context-global.md`
  - Project: `.shooter/config/nvim/shooter-context-project.md` (relative to git root)
  - Format: Plain markdown, injected into shot messages

**Image Storage:**
- Directory: `.shooter/config/nvim/images/` (in git repo)
- Managed by: `lua/shooter/tools/clipboard_image.lua`
- Git handling: .gitignore created to exclude images, .gitkeep for directory tracking

## Process Communication

**Tmux Pane Communication:**
- Text transmission: tmux load-buffer + paste-buffer for large messages
- Paste mode: bracketed paste (enabled with `-p` flag)
- Send delays: adaptive based on text size
  - Small: 0.2s (configurable via tmux.delay)
  - Medium: 0.5-1.0s
  - Large: 1.5-2.5s
- Pre-send sequence: Ctrl+C (cancel), Ctrl+U (clear line)
- Post-send: two Enter keypresses to execute

**Process Detection:**
- Uses: `ps aux | grep <pattern>`
- TTY extraction: `ps aux ... | awk '{print $7}'`
- TTY parsing: Matches `ttys\d+` or `s\d+` patterns
- Purpose: Find which pane (TTY) has the AI process running

## Webhooks & Callbacks

**None detected** - This is a local Neovim plugin with no inbound webhooks or HTTP servers.

## Authentication & Secrets

**Not applicable** - Plugin does not handle authentication directly.
- Claude and OpenCode CLI manage their own auth (stored in home directory)
- No API keys stored by shooter.nvim
- Environment-based: relies on `~/.config/claude` and similar CLI configs

## Monitoring & Observability

**Health Checks:**
- Location: `lua/shooter/health.lua`, `lua/shooter/health/tools.lua`
- Checks performed:
  - Plugin dependencies (telescope, oil.nvim, vim-i3wm-tmux-navigator)
  - External tools (tmux, git, ttok, hal)
  - Terminal detection (iTerm, tmux session)
  - AI process detection (Claude or OpenCode running)
  - Config file existence (global and project context)
- Invoked via: `:checkhealth shooter`

**Logging:**
- Uses: `vim.notify()` for user notifications
- No persistent logs - all output to Neovim UI
- Debug output: conditional echo statements in modules

## Environment Configuration

**Required Environment:**
- `TMUX` - tmux session identifier (optional but strongly recommended)
- `TERM_PROGRAM` - terminal type (checked for iTerm support)

**User Configuration Directory:**
- `~/.config/shooter.nvim/`
  - Contains: global context file, session storage, cached data

**Project Configuration:**
- `.shooter/shotfiles/` - shot files for the project
- `.shooter/config/nvim/` - project context files
- `.shooter/config/nvim/images/` - project images
- `.shot-queue.json` - shot queue state (optional)

## Cross-CLI Support

**Provider Abstraction:**
- Supports multiple AI backends without code changes
- Providers register in: `lua/shooter/providers/init.lua`
- Each provider implements:
  - `send_file_reference(pane_id, filepath)` - send @ reference
  - `send_text(pane_id, text)` - send arbitrary text
  - `build_shot_message(bufnr, shot_info)` - format shot message
  - `build_multishot_message(bufnr, shot_infos)` - format batch message
  - `get_create_command()` - command to start new pane
  - `supports_auto_create()` - bool flag

**Current Providers:**
- Claude: `lua/shooter/providers/claude.lua`
- OpenCode: `lua/shooter/providers/opencode.lua`

**Response Viewers:**
- Location: `lua/shooter/tools/response_viewer/`
- Providers: `claude.lua`, `opencode.lua`
- Purpose: View and interact with AI responses in new buffer

## System Integration Points

**Git Integration:**
- Repo detection: `git rev-parse --show-toplevel`
- Used for: session storage paths, analytics by project
- Files: `lua/shooter/core/files.lua`

**Clipboard Integration:**
- System clipboard check: external clipboard-image script
- Script location: `scripts/shooter-clipboard-image`
- Script calls: `check`, `save` subcommands
- Platform support: macOS (pngpaste), Linux (xclip)

**Obsidian Integration (Optional):**
- If Obsidian vault is set up in `.shooter/config/nvim/obsidian/`
- Provides: Markdown link conversion for Obsidian notes
- File: `lua/shooter/tools/obsidian.lua`

---

*Integration audit: 2026-02-08*
