# External Integrations

**Analysis Date:** 2026-01-30

## APIs & External Services

**AI Providers:**
- **Claude Code CLI** - Primary AI integration for sending shots
  - SDK/Client: Direct CLI invocation via tmux send
  - File path format: `@filepath` syntax support in `lua/shooter/providers/claude.lua`
  - Detection: Process pattern matching `claude`
  - Location: `lua/shooter/providers/claude.lua` (lines 1-46)

- **OpenCode CLI** - Alternative AI provider (supported in parallel)
  - Implementation: `lua/shooter/providers/opencode.lua`
  - Same message sending interface as Claude provider
  - Process pattern matching for detection

## Data Storage

**Databases:**
- None - Shooter.nvim is a stateless plugin (no persistent data backend)

**File Storage:**
- **Local filesystem only**
  - Shot files: Markdown format in `plans/prompts/` (user configurable in `lua/shooter/config.lua`)
  - Session files: YAML format in `~/.config/shooter.nvim/sessions/<owner>_<repo>/` per-repository
  - Queue file: JSON format at `plans/prompts/.shot-queue.json`
  - Images: `~/.clipboard-images/` or `.shooter.nvim/images/` (configurable)
  - Context files: Global `~/.config/shooter.nvim/shooter-context-global.md` and project `.shooter.nvim/shooter-context-project.md`

**Session Persistence:**
- **Format:** YAML (custom serializer in `lua/shooter/session/storage.lua`)
- **Location:** `~/.config/shooter.nvim/sessions/`
- **Schema:** `lua/shooter/session/defaults.lua`
  - vimMode settings (shotfilePicker, projectPicker, sortPicker modes)
  - Filters (projects root/sub, folders)
  - Sort criteria with priority and direction
  - Layout preference (vertical/horizontal)
- **Operations:** `lua/shooter/session/picker.lua`, `lua/shooter/session/init.lua`

**Caching:**
- Filter state cache in memory: `lua/shooter/filter_state.lua` (not persistent)
- No external cache service

## Authentication & Identity

**Auth Provider:**
- None - Plugin uses host system context (Git, tmux user, etc.)
- No user login required

**AI Provider Access:**
- Claude Code CLI runs in authenticated tmux pane
- Credentials handled by Claude CLI process, not by shooter.nvim
- Shot content + context sent as plain text via tmux

## Monitoring & Observability

**Error Tracking:**
- None - Plugin uses Neovim notifications for user feedback
- Notifications via `vim.notify()` throughout codebase

**Logs:**
- **Health Check:** `lua/shooter/health.lua`
  - Verifies: Plugin initialization, Neovim version, Telescope installed, Tmux available
  - Checks: Claude/OpenCode CLI running, Git available, Obsidian vault present
  - Checks: Optional tools (ttok, hal, gp.nvim)
- **Shell Execution Tracking:** `lua/shooter/tmux/send.lua` calculates delays for message transmission
- **Execution Status:** Shots marked with timestamp when executed (inline in markdown files)

**Debug Information:**
- Available via `:ShooterHealth` command (registered in `lua/shooter/commands.lua`)
- No verbose logging output; relies on notifications

## File System Interaction

**Path Resolution:**
- Git root detection: `git rev-parse --show-toplevel` (in `lua/shooter/core/files.lua`)
- Relative path computation for panes and projects
- Symlink expansion for config directories
- Environment variable expansion: `~/.config/`, `~/.clipboard-images/` via `vim.fn.expand()`

**File Operations:**
- **Reading:** Markdown shot files with pattern matching
  - Shot header pattern: `^##\s+x?\s*shot` (open or executed)
  - Markdown parsing in `lua/shooter/core/shots.lua`
- **Writing:** Shot execution marking (adds `x` prefix and timestamp)
- **Directories:** Creation via `vim.fn.mkdir(path, 'p')` (recursive)

## CI/CD & Deployment

**Hosting:**
- GitHub repository: `divramod/shooter.nvim`
- Plugin registry: Lazy.nvim, Packer.nvim compatible

**CI Pipeline:**
- Plenary.nvim testing: `:PlenaryBustedDirectory tests/`
- No automated CI service configured (local testing only)

**Distribution:**
- Plugin uploaded to GitHub releases
- Installed via plugin managers pointing to GitHub repo

## Environment Configuration

**Required env vars:**
- `TMUX` - Checked to detect if running in tmux session (optional but required for send functionality)
- `HOME` - Used for config directory paths

**Optional env vars:**
- `CLAUDE_*` - Claude CLI authentication (handled by Claude CLI process)

**Secrets location:**
- No secrets stored in plugin code
- AI credentials managed by tmux pane running Claude CLI
- All text transmission is plain text through tmux buffer

## Webhooks & Callbacks

**Incoming:**
- None - Plugin is event-driven by user actions in Neovim

**Outgoing:**
- **Tmux Send Events:** Shots sent to tmux panes via `tmux send-keys` command
  - Implementation: `lua/shooter/tmux/send.lua`
  - Escape sequence handling: `vim.fn.system()` execution of tmux commands
  - Temporary file usage for large messages (content written to `/tmp/` via `os.tmpname()`)

## External Tool Integration Points

**Obsidian:**
- Vault detection: Walking up directory tree looking for `.obsidian/` directory
- URI scheme: `obsidian://open?vault=<name>&file=<path>` in `lua/shooter/tools/obsidian.lua`
- Activation: `open` (macOS) or `xdg-open` (Linux)
- Location: `lua/shooter/tools/obsidian.lua` (lines 1-102)

**Token Counter (ttok CLI):**
- Command: `ttok < filename` (piped input)
- Output: Plain number (token count)
- Error handling: Checks if `ttok` is executable (`vim.fn.executable('ttok')`)
- Location: `lua/shooter/tools/token_counter.lua`

**Image Handling:**
- **Clipboard Detection:** `scripts/shooter-clipboard-image check` (exit code 0 if image in clipboard)
- **Image Saving:** `scripts/shooter-clipboard-image save <directory>`
- **Clipboard Script:** Located at `scripts/shooter-clipboard-image` (bash script)
- **Implementation:** `lua/shooter/tools/clipboard_image.lua`
- **Integration:** Smart paste on `p`, `P`, `Ctrl-V` in keymaps (`lua/shooter/keymaps.lua`)

**Voice Input (gp.nvim Optional):**
- If gp.nvim installed: `<space>e` triggers voice dictation
- Conditional loading in `lua/shooter/keymaps.lua` (graceful fallback if not installed)

**Image Picking (hal CLI Optional):**
- Command: `hal` CLI invocation for image selection
- Used with `<space>I` command for image insertion
- Health check in `lua/shooter/health/tools.lua`
- Implementation: `lua/shooter/images.lua`

## System Command Integration

**Tmux Commands Used:**
- `tmux send-keys -t <pane> <text>` - Send text to pane
- `tmux split-window` - Create new pane
- `tmux list-panes -F` - List available panes with format
- `tmux display-message` - Get pane information
- `tmux resize-pane` - Resize panes
- Implementation: `lua/shooter/tmux/operations.lua`, `lua/shooter/tmux/wrapper.lua`

**Git Commands Used:**
- `git rev-parse --show-toplevel` - Get repository root
- Usage: `lua/shooter/core/files.lua`, `lua/shooter/tools/clipboard_image.lua`

**System Utilities:**
- `ls -1`, `ls -d` - Directory listing
- `find` - File discovery
- `ps aux | grep` - Process detection
- Shell execution via `io.popen()`, `vim.fn.system()`, `os.execute()`
- Locations: `lua/shooter/core/repos.lua`, `lua/shooter/health.lua`, `lua/shooter/providers/init.lua`

## Message Flow Architecture

**Shot Sending Pipeline:**
1. User selects shot in telescope picker
2. Message builder: `lua/shooter/tmux/messages.lua` constructs message with context
3. Context injection: `lua/shooter/core/context.lua`, `lua/shooter/context/resolvers.lua`
4. Delay calculation based on message size: `lua/shooter/tmux/send.lua`
5. Temporary file write for large messages: `lua/shooter/tmux/send.lua` (lines 66-75)
6. Tmux execution: `vim.fn.system()` with `tmux send-keys` command
7. Escape sequences: Clear line, reset state before sending

**Multi-shot Sending:**
- Similar flow but with multishot delay calculation
- Implementation: `lua/shooter/tmux/operations.lua`

## Configuration File Formats

**YAML Sessions:**
- Custom parser/serializer (no external YAML library)
- Fields: `name`, `vimMode`, `filters`, `sortBy`, `layout`
- Location: `lua/shooter/session/storage.lua` (lines 44-73 serialize, 78-152 parse)

**JSON Queue:**
- Queue file format for batched shot execution
- Location: `plans/prompts/.shot-queue.json` (default)
- Structure: `lua/shooter/queue/storage.lua`

**Markdown Shot Files:**
- Format: Headers with `## shot N` or `## x shot N` (executed)
- Timestamp appended on execution: `[timestamp: YYYY-MM-DD HH:MM:SS]`
- Context files in markdown with template injection
- Parser: `lua/shooter/core/shots.lua`

**Context Templates:**
- Global template: `~/.config/shooter.nvim/shooter-context-global.md`
- Project template: `.shooter.nvim/shooter-context-project.md`
- Message template: `templates/shooter-context-message.md`
- Template variables: Repository name, file paths, shot header
- Processing: `lua/shooter/core/templates.lua`, `lua/shooter/tmux/messages.lua`

---

*Integration audit: 2026-01-30*
