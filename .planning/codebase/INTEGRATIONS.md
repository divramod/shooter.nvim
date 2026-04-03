# External Integrations

**Analysis Date:** 2026-04-03

## AI Agent Providers

shooter.nvim communicates with AI coding agents running in tmux panes. It does not call AI APIs directly -- it sends text/file references to CLI tools via tmux.

**Provider Architecture:**
- Registry pattern in `lua/shooter/providers/init.lua`
- Each provider implements: `send_file_reference()`, `send_text()`, `build_shot_message()`, `build_multishot_message()`, `get_create_command()`, `supports_auto_create()`
- Detection: tmux pane variable `@shooter_provider` (set by hal), with ps-based TTY fallback

**Claude Code:**
- Provider: `lua/shooter/providers/claude.lua`
- Process pattern: `claude`
- Create command: `claude`
- File reference: `@filepath` syntax via tmux send-keys
- Response viewer: `lua/shooter/tools/response_viewer/claude.lua`

**OpenCode:**
- Provider: `lua/shooter/providers/opencode.lua`
- Process pattern: `opencode`
- Create command: `opencode -c`
- File reference: `@filepath` with Escape to dismiss autocomplete before Enter
- Response viewer: `lua/shooter/tools/response_viewer/opencode.lua`

**Codex (OpenAI):**
- Provider: `lua/shooter/providers/codex.lua`
- Process pattern: `codex`
- Create command: `codex`
- File reference: Sends literal filepath (no `@` prefix, causes stalls in Codex)

**Gemini:**
- Provider: `lua/shooter/providers/gemini.lua`
- Process pattern: `gemini`
- Create command: `gemini`
- File reference: Sends `run cat <filepath> and follow the instructions in that file` (Gemini TUI has issues with `@filepath` and paste)
- Special handling: Escape to normal mode, `i` to enter insert mode before sending text

**GitHub Copilot:**
- Provider: `lua/shooter/providers/copilot.lua`
- Process pattern: `copilot`
- Create command: `copilot`
- File reference: `@filepath` with Escape to dismiss autocomplete before Enter (same as OpenCode)

## Tmux

**Core Integration:**
- All AI communication goes through tmux (`lua/shooter/tmux/`)
- Two send modes configured via `tmux.send_mode`:
  - `paste` mode: Uses `tmux load-buffer` + `paste-buffer -p` (fast, shows "[pasted]")
  - `keys` mode: Uses `tmux send-keys` (`lua/shooter/tmux/keys.lua`, slower, shows in history)
- Pane detection: `lua/shooter/tmux/detect.lua`
- Pane creation: `lua/shooter/tmux/create.lua`
- Message building: `lua/shooter/tmux/messages.lua`
- Text sending: `lua/shooter/tmux/send.lua`
- Shell command execution via `io.popen()` and `vim.fn.jobstart()`

**Pane Management:**
- Toggle panes: `lua/shooter/tmux/toggle_panes.lua`
- Config panes: `lua/shooter/tmux/config_panes.lua`
- Script panes: `lua/shooter/tmux/script_panes.lua`
- Hidden sessions: `lua/shooter/tmux/hidden_session.lua`
- Watch mode: `lua/shooter/tmux/watch.lua`
- Renumbering: `lua/shooter/tmux/renumber_helper.lua`

## Telescope.nvim

**Picker Integration:**
- Shot picker with preview: `lua/shooter/telescope/pickers.lua`
- Custom actions: `lua/shooter/telescope/actions.lua`
- Custom previewers: `lua/shooter/telescope/previewers.lua`
- Toggle panes picker: `lua/shooter/telescope/toggle_panes_picker.lua`
- Helper utilities: `lua/shooter/telescope/helpers.lua`
- Picker help overlay: `lua/shooter/telescope/picker_help.lua`

## Oil.nvim

**File Management:**
- Custom keymaps for Oil buffers: `lua/shooter/keymaps/oil.lua`
- Used for file navigation and management within shooter directories
- Clipboard image directory opens via Oil: `lua/shooter/tools/clipboard_image.lua` (`open_images_dir()`)

## Obsidian

**Vault Integration:**
- Module: `lua/shooter/tools/obsidian.lua`
- Opens current file in Obsidian app via `obsidian://open` URI scheme
- Vault detection: walks up directory tree looking for `.obsidian/` directory
- Platform: `open` (macOS) or `xdg-open` (Linux)
- No API keys or credentials required

## Data Storage

**Databases:**
- None; all data is file-based

**File Storage:**
- Shot files: `.shooter/ai/shotfiles/*.md` (markdown, user-authored)
- Queue: `.shooter/ai/shotfiles/.shot-queue.json` (JSON array)
- Sessions: `~/.config/shooter/nvim/sessions/<owner>/<repo>/` (YAML files, `lua/shooter/session/storage.lua`)
- Global context: `~/.config/shooter/nvim/shooter-context-global.md`
- Project context: `.shooter/config/nvim/shooter-context-project.md`
- Clipboard images: `<git-root>/.shooter/config/nvim/images/` (gitignored except .gitkeep)

**Caching:**
- None

## Token Counting (ttok)

**Integration:**
- Module: `lua/shooter/tools/token_counter.lua`
- Uses `ttok` CLI (Python package by Simon Willison)
- Invoked via `io.popen('ttok < <filepath>')`
- Displays formatted token count for current file

## Clipboard Image Detection

**Integration:**
- Module: `lua/shooter/tools/clipboard_image.lua`
- Script: `scripts/shooter-clipboard-image` (bash)
- macOS only: uses `osascript` (AppleScript) to detect image types in clipboard
- Saves clipboard images via `pngpaste` or AppleScript
- Smart paste: intercepts `p`, `P`, `Ctrl-V` to check for clipboard images first

## Sound

**Integration:**
- Module: `lua/shooter/sound.lua`
- macOS only: uses `afplay` to play sound on shot send
- Configurable sound file and volume via `sound.*` config keys
- Default: `/System/Library/Sounds/Pop.aiff`

## hal CLI

**Integration:**
- Optional dependency for image picking (`ShoImages` command)
- Health check: `lua/shooter/health/tools.lua`
- Sets `@shooter_provider` tmux pane variable when launching agents

## gp.nvim (GpWhisper)

**Integration:**
- Optional dependency for voice dictation
- Checked via `vim.fn.exists(':GpWhisper')` in health checks
- Keymap: `<space>e` for voice dictation

## Authentication & Identity

**Auth Provider:**
- Not applicable; shooter.nvim does not authenticate with any service
- AI providers handle their own authentication externally

## Monitoring & Observability

**Error Tracking:**
- None; errors reported via `vim.notify()` and `vim.health`

**Logs:**
- No persistent logging; uses `vim.notify()` for user-facing messages

## CI/CD & Deployment

**Hosting:**
- Distributed as a Neovim plugin (git repository)

**CI Pipeline:**
- Not detected in repository root

## Environment Configuration

**Required env vars:**
- `TMUX` - Must be set (running inside tmux)

**Optional env vars:**
- `TERM_PROGRAM` - Checked for iTerm detection in health checks

**Secrets location:**
- No secrets managed by this plugin; AI credentials managed by respective CLI tools

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

---

*Integration audit: 2026-04-03*
