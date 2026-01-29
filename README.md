# shooter.nvim

A Neovim plugin for managing iterative development workflows with shots (numbered work items), tmux integration, and context-aware AI collaboration.

## Table of Contents

- [Terminology](#terminology)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Commands](#commands)
- [Default Keybindings](#default-keybindings)
- [Configuration](#configuration)
- [Context Files](#context-files)
- [Template System](#template-system)
- [File Structure](#file-structure)
- [Project Support](#project-support)
- [Shot Format](#shot-format)
- [Health Check](#health-check)
- [Sound Notifications](#sound-notifications)
- [Tips](#tips)
- [Troubleshooting](#troubleshooting)
- [License](#license)
- [Credits](#credits)

## Terminology

| Term | Description |
|------|-------------|
| **Shots File** | The markdown file you edit in Neovim containing multiple shots (e.g., `20260118_0516_feature.md`) |
| **Shot** | A numbered work item within a shots file (e.g., `## shot 5`) |
| **Shot History File** | The file sent to Claude via `@filepath` syntax, saved to `~/.config/shooter.nvim/history/` |
| **Context File** | Global or project-specific instructions injected with each shot |

## Features

- 📝 **Shot-based workflow**: Break down features into numbered, executable shots
- 🔄 **Tmux integration**: Send shots directly to Claude (or other AI) running in tmux panes
- 🎯 **Context injection**: Automatically includes general and project-specific context
- 📂 **File organization**: Move files between folders (archive, backlog, done, etc.)
- 🔍 **Telescope integration**: Powerful pickers for files, shots, and queues
- 📋 **Queue system**: Queue shots for later execution across multiple panes
- ✅ **Shot tracking**: Mark shots as executed with timestamps
- 🖼️ **Image insertion**: Reference images in your shots
- 🎨 **Syntax highlighting**: Visual distinction between open and done shots

## Requirements

- Neovim >= 0.9.0
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [oil.nvim](https://github.com/stevearc/oil.nvim) - file management and movement commands
- [vim-i3wm-tmux-navigator](https://github.com/fogine/vim-i3wm-tmux-navigator) - seamless navigation between vim splits and tmux panes
- tmux (for sending to AI panes)
- Claude CLI or similar AI tool (optional, for send functionality)
- [gp.nvim](https://github.com/Robitx/gp.nvim) (optional, for voice dictation with `<space>e`)
- hal CLI (optional, for image picking with `<space>I`)
- [ttok](https://github.com/simonw/ttok) (optional, for token counting with `<space>ttc`)

## Installation

### lazy.nvim

```lua
{
  'divramod/shooter.nvim',
  dependencies = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/plenary.nvim',
    'stevearc/oil.nvim',
    'fogine/vim-i3wm-tmux-navigator',
  },
  cmd = {
    'ShooterCreate', 'ShooterList', 'ShooterOpenShots',
    'ShooterSend1', 'ShooterSendAll1', 'ShooterQueueView',
  },
  keys = {
    { '<space>n', '<cmd>ShooterCreate<cr>', desc = 'Shooter: Create file' },
    { '<space>o', '<cmd>ShooterOpenShots<cr>', desc = 'Shooter: Open shots' },
    { '<space>v', '<cmd>ShooterList<cr>', desc = 'Shooter: List files' },
    { '<space>1', '<cmd>ShooterSend1<cr>', desc = 'Shooter: Send to pane 1' },
    { '<space>h', '<cmd>ShooterHelp<cr>', desc = 'Shooter: Help' },
  },
  config = function()
    require('shooter').setup({
      -- Optional: override defaults
      paths = {
        global_context = '~/.config/shooter.nvim/shooter-context-global.md',
        prompts_root = 'plans/prompts',
      },
      keymaps = {
        enabled = true,  -- Enable default keymaps
      },
    })
  end,
}
```

### packer.nvim

```lua
use {
  'divramod/shooter.nvim',
  requires = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/plenary.nvim',
    'stevearc/oil.nvim',
    'fogine/vim-i3wm-tmux-navigator',
  },
  config = function()
    require('shooter').setup()
  end,
}
```

## Quick Start

1. **Create a new shots file**:
   ```
   :ShooterCreate
   ```
   Enter a feature name when prompted. This creates a timestamped markdown file in `plans/prompts/`.

2. **Add shots to your file** (latest shot at top):
   ```markdown
   # 2026-01-21 - Add user authentication

   ## shot 2
   Create registration endpoint

   ## shot 1
   Set up database schema for users table
   ```

3. **Send a shot to Claude** (in tmux):
   - Place cursor in shot 2
   - Press `<space>1` (or `:ShooterSend1`)
   - If no Claude pane exists, one is automatically created to the left
   - Shot content + context is sent to Claude

4. **View open shots**:
   ```
   :ShooterOpenShots
   ```
   - Shows all unexecuted shots in current file
   - Press `Tab` to multi-select
   - Press `1-4` to send to Claude pane

## Commands

Commands are organized into 8 namespaces. Old command names work as aliases.

### Shotfile Commands (`ShooterShotfile*`)

| Command | Alias | Description |
|---------|-------|-------------|
| `:ShooterShotfileNew` | `:ShooterCreate` | Create new shots file |
| `:ShooterShotfileNewInRepo` | `:ShooterCreateInRepo` | Create in another repo |
| `:ShooterShotfilePicker` | `:ShooterList` | Telescope picker for files |
| `:ShooterShotfilePickerAll` | `:ShooterListAll` | Picker for all repos |
| `:ShooterShotfileLast` | `:ShooterLast` | Open last edited file |
| `:ShooterShotfileRename` | | Rename current shotfile |
| `:ShooterShotfileDelete` | | Delete current shotfile |
| `:ShooterShotfileOpenPrompts` | `:ShooterOpenPrompts` | Oil prompts folder |
| `:ShooterShotfileHistory` | `:ShooterOpenHistory` | History directory (Oil) |
| `:ShooterShotfileMoveArchive` | `:ShooterArchive` | Move to archive/ |
| `:ShooterShotfileMoveBacklog` | `:ShooterBacklog` | Move to backlog/ |
| `:ShooterShotfileMoveDone` | `:ShooterDone` | Move to done/ |
| `:ShooterShotfileMovePrompts` | `:ShooterPrompts` | Move to prompts/ |
| `:ShooterShotfileMoveReqs` | `:ShooterReqs` | Move to reqs/ |
| `:ShooterShotfileMoveTest` | `:ShooterTest` | Move to test/ |
| `:ShooterShotfileMoveWait` | `:ShooterWait` | Move to wait/ |
| `:ShooterShotfileMoveGitRoot` | `:ShooterGitRoot` | Move to git root |
| `:ShooterShotfileMovePicker` | `:ShooterMovePicker` | Fuzzy folder picker |

### Shot Commands (`ShooterShot*`)

| Command | Alias | Description |
|---------|-------|-------------|
| `:ShooterShotNew` | `:ShooterNewShot` | Add new shot |
| `:ShooterShotNewWhisper` | `:ShooterNewShotWhisper` | New shot + whisper |
| `:ShooterShotDelete` | `:ShooterDeleteLastShot` | Delete last shot |
| `:ShooterShotToggle` | `:ShooterToggleDone` | Toggle done status |
| `:ShooterShotDeleteCursor` | `:ShooterDeleteShotUnderCursor` | Delete shot at cursor |
| `:ShooterShotMove` | `:ShooterMoveShot` | Move shot to another file |
| `:ShooterShotMunition` | `:ShooterMunition` | Import from inbox |
| `:ShooterShotPicker` | `:ShooterOpenShots` | Open shots picker |
| `:ShooterShotNavNext` | `:ShooterNextShot` | Next open shot |
| `:ShooterShotNavPrev` | `:ShooterPrevShot` | Previous open shot |
| `:ShooterShotNavNextSent` | `:ShooterNextSent` | Next sent shot |
| `:ShooterShotNavPrevSent` | `:ShooterPrevSent` | Previous sent shot |
| `:ShooterShotNavLatest` | `:ShooterLatestSent` | Latest sent shot |
| `:ShooterShotNavUndo` | `:ShooterUndoLatestSent` | Undo sent marking |
| `:ShooterShotSend{1-9}` | `:ShooterSend{1-9}` | Send shot to pane |
| `:ShooterShotSendAll{1-9}` | `:ShooterSendAll{1-9}` | Send all shots |
| `:ShooterShotSendVisual{1-9}` | `:ShooterSendVisual{1-9}` | Send selection |
| `:ShooterShotResend{1-9}` | `:ShooterResend{1-9}` | Resend latest |
| `:ShooterShotQueue{1-4}` | `:ShooterQueueAdd{1-4}` | Queue for pane |
| `:ShooterShotQueueView` | `:ShooterQueueView` | View queue |
| `:ShooterShotQueueClear` | `:ShooterQueueClear` | Clear queue |

### Tmux Commands (`ShooterTmux*`)

| Command | Description |
|---------|-------------|
| `:ShooterTmuxZoom` | Toggle pane zoom |
| `:ShooterTmuxEdit` | Edit pane in vim |
| `:ShooterTmuxGit` | Git status toggle |
| `:ShooterTmuxLight` | Light/dark toggle |
| `:ShooterTmuxKillOthers` | Kill other panes |
| `:ShooterTmuxReload` | Reload session |
| `:ShooterTmuxDelete` | Delete session picker |
| `:ShooterTmuxSmug` | Smug load |
| `:ShooterTmuxYank` | Yank pane to vim |
| `:ShooterTmuxChoose` | Choose session |
| `:ShooterTmuxSwitch` | Switch to last |
| `:ShooterTmuxWatch` | Watch pane |
| `:ShooterTmuxPaneToggle{0-9}` | Toggle pane visibility |

### Subproject Commands (`ShooterSubproject*`)

| Command | Description |
|---------|-------------|
| `:ShooterSubprojectNew` | Create new subproject |
| `:ShooterSubprojectList` | List subprojects |
| `:ShooterSubprojectEnsure` | Ensure standard folders |

### Tool Commands (`ShooterTool*`)

| Command | Alias | Description |
|---------|-------|-------------|
| `:ShooterToolToken` | `:ShooterToolTokenCounter` | Token counter |
| `:ShooterToolObsidian` | `:ShooterOpenObsidian` | Open in Obsidian |
| `:ShooterToolImages` | `:ShooterImages` | Insert images |
| `:ShooterToolPrd` | `:ShooterPrdList` | PRD list |
| `:ShooterToolGreenkeep` | `:ShooterGreenkeep` | Greenkeep |

### Cfg Commands (`ShooterCfg*`)

| Command | Alias | Description |
|---------|-------|-------------|
| `:ShooterCfgGlobal` | `:ShooterEditGlobalContext` | Edit global context |
| `:ShooterCfgProject` | `:ShooterEditProjectContext` | Edit project context |
| `:ShooterCfgPlugin` | `:ShooterEditConfig` | Edit plugin config |
| `:ShooterCfgShot` | `:ShooterShotCfg` | Shot picker config |
| `:ShooterCfgShotfile` | `:ShooterShotfileCfg` | Shotfile picker config |

### Analytics Commands (`ShooterAnalytics*`)

| Command | Description |
|---------|-------------|
| `:ShooterAnalyticsProject` | Project analytics |
| `:ShooterAnalyticsGlobal` | Global analytics |

### Help Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `:ShooterHelp` | | Show help |
| `:ShooterHealth` | | Health check |
| `:ShooterHelpDashboard` | `:ShooterDashboard` | Dashboard |

### Utility Commands

| Command | Description |
|---------|-------------|
| `:ShooterHistoryAudit` | Audit history (! to fix) |
| `:ShooterHistoryCleanup` | Cleanup duplicates (! to delete) |
| `:ShooterHistoryMigrate` | Migrate history files |

## Default Keybindings

All keybindings use `<space>` prefix (customizable). Commands are organized into 8 namespaces:

### Core Shortcuts (root level)

| Key | Action |
|-----|--------|
| `<space>n` | Create new shots file |
| `<space>s` | New shot |
| `<space>o` | Open shots picker |
| `<space>v` | Shotfile picker |
| `<space>1-4` | Send shot to pane 1-4 |

### Shotfile Namespace (`<space>f`)

| Key | Action |
|-----|--------|
| `<space>fn` | New shotfile |
| `<space>fN` | New in other repo |
| `<space>fp` | Shotfile picker |
| `<space>fP` | All repos picker |
| `<space>fl` | Last edited file |
| `<space>fr` | Rename current |
| `<space>fd` | Delete current |
| `<space>fo` | Oil prompts folder |
| `<space>fi` | History (Oil) |
| `<space>fma` | Move to archive |
| `<space>fmb` | Move to backlog |
| `<space>fmd` | Move to done |
| `<space>fmp` | Move to prompts |
| `<space>fmr` | Move to reqs |
| `<space>fmt` | Move to test |
| `<space>fmw` | Move to wait |
| `<space>fmg` | Move to git root |
| `<space>fmm` | Fuzzy folder picker |

### Shot Namespace (`<space>s`)

| Key | Action |
|-----|--------|
| `<space>ss` | New shot |
| `<space>sS` | New shot + whisper |
| `<space>sd` | Delete last shot |
| `<space>sD` | Delete shot at cursor |
| `<space>s.` | Toggle done |
| `<space>sm` | Move shot to another file |
| `<space>sM` | Import from inbox (Munition) |
| `<space>sp` | Open shots picker |
| `<space>s]` | Next open shot |
| `<space>s[` | Prev open shot |
| `<space>s}` | Next sent shot |
| `<space>s{` | Prev sent shot |
| `<space>sL` | Latest sent |
| `<space>su` | Undo sent marking |
| `<space>s1-4` | Send to pane |
| `<space>sR1-4` | Resend to pane |
| `<space>sq1-4` | Queue for pane |
| `<space>sqQ` | View queue |

### Tmux Namespace (`<space>t`)

| Key | Action |
|-----|--------|
| `<space>tz` | Zoom toggle |
| `<space>te` | Edit pane in vim |
| `<space>tg` | Git status toggle |
| `<space>ti` | Light/dark toggle |
| `<space>to` | Kill other panes |
| `<space>tr` | Reload session |
| `<space>td` | Delete session |
| `<space>ts` | Smug load |
| `<space>ty` | Yank pane to vim |
| `<space>tc` | Choose session |
| `<space>tp` | Switch to last |
| `<space>tw` | Watch pane |
| `<space>t0-9` | Toggle pane visibility |

### Subproject Namespace (`<space>p`)

| Key | Action |
|-----|--------|
| `<space>pn` | New subproject |
| `<space>pl` | List subprojects |
| `<space>pe` | Ensure standard folders |

### Tools Namespace (`<space>l`)

| Key | Action |
|-----|--------|
| `<space>lt` | Token counter |
| `<space>lo` | Open in Obsidian |
| `<space>li` | Insert images |
| `<space>lw` | Watch pane |
| `<space>lp` | PRD list |
| `<space>lc` | Paste clipboard image |
| `<space>lI` | Open clipboard images folder |

### Smart Paste (Global Keymaps)

Automatically paste clipboard images instead of text when an image is in the clipboard.
Images are saved to `<repo>/.shooter.nvim/images/clipboard_YYYYMMDD_HHMMSS.png`.

| Key | Action |
|-----|--------|
| `p` | Smart paste after (image or text) |
| `P` | Smart paste before (image or text) |
| `<C-v>` | Smart paste from clipboard (normal & insert mode) |

Disable with `keymaps.smart_paste = false` in config.

### Cfg Namespace (`<space>c`)

| Key | Action |
|-----|--------|
| `<space>cg` | Edit global context |
| `<space>cp` | Edit project context |
| `<space>ce` | Edit plugin config |
| `<space>cs` | Shot picker config |
| `<space>cf` | Shotfile picker config |

### Analytics Namespace (`<space>a`)

| Key | Action |
|-----|--------|
| `<space>aa` | Project analytics |
| `<space>aA` | Global analytics |

### Help Namespace (`<space>h`)

| Key | Action |
|-----|--------|
| `<space>hh` | Show help |
| `<space>hH` | Health check |
| `<space>hd` | Dashboard |

### Send All

| Key | Action |
|-----|--------|
| `<space><space>1-4` | Send ALL open shots to pane |

### Shotfile Picker (`<space>v`)

In normal mode within the file picker:

| Key | Action |
|-----|--------|
| `1` or `a` | Toggle archive folder |
| `2` or `b` | Toggle backlog folder |
| `3` or `t` | Toggle done folder |
| `4` or `e` | Toggle reqs folder |
| `5` or `w` | Toggle wait folder |
| `6` or `f` | Toggle prompts folder |
| `A` | Enable ALL folders |
| `c` or `C` | Reset folders to default (prompts only) |
| `P` | Project picker |
| `S` | Sort picker |
| `ss` | Save session |
| `sl` | Load session |
| `sn` | New session |
| `sd` | Delete session |
| `sr` | Rename session |
| `?` | Show all keymaps |

Sessions are saved per-repo in `~/.config/shooter.nvim/sessions/<repo>/`.

## Configuration

All configuration options with their default values:

```lua
require('shooter').setup({
  -- ═══════════════════════════════════════════════════════════════════════════
  -- PATH CONFIGURATION
  -- ═══════════════════════════════════════════════════════════════════════════
  paths = {
    -- Global context file (shared across all projects)
    global_context = '~/.config/shooter.nvim/shooter-context-global.md',

    -- Project context file (relative to git root)
    project_context = '.shooter.nvim/shooter-context-project.md',

    -- Project context template (in plugin installation)
    project_template = 'templates/shooter-context-project-template.md',

    -- Message template for context injection
    message_template = 'templates/shooter-context-message.md',

    -- Queue file location (relative to cwd)
    queue_file = 'plans/prompts/.shot-queue.json',

    -- Prompts root directory (relative to cwd)
    prompts_root = 'plans/prompts',
  },

  -- ═══════════════════════════════════════════════════════════════════════════
  -- TMUX CONFIGURATION
  -- ═══════════════════════════════════════════════════════════════════════════
  tmux = {
    -- Delay between send operations (seconds)
    delay = 0.2,

    -- Delay for long messages (seconds)
    long_delay = 1.5,

    -- Maximum number of panes supported
    max_panes = 9,

    -- Threshold for long messages (characters)
    long_message_threshold = 5000,

    -- Threshold for long messages (lines)
    long_message_lines = 50,

    -- Send mode: 'paste' (fast, shows "[pasted]" in history)
    --            'keys' (slower, shows full text in shell history)
    send_mode = 'keys',
  },

  -- ═══════════════════════════════════════════════════════════════════════════
  -- TELESCOPE CONFIGURATION
  -- ═══════════════════════════════════════════════════════════════════════════
  telescope = {
    -- Layout strategy for pickers
    layout_strategy = 'vertical',

    -- Layout configuration
    layout_config = {
      width = 0.9,
      height = 0.9,
      preview_height = 0.5,
    },
  },

  -- ═══════════════════════════════════════════════════════════════════════════
  -- KEYMAP CONFIGURATION
  -- ═══════════════════════════════════════════════════════════════════════════
  keymaps = {
    -- Enable default keymaps (set to false to define your own)
    enabled = true,

    -- Key prefix (default: space)
    prefix = ' ',

    -- Move command prefix (result: <space>m{a|b|d|...})
    move_prefix = 'm',

    -- Copy command prefix
    copy_prefix = 'c',

    -- Enable smart paste (p, P, Ctrl-V check for clipboard images)
    smart_paste = true,
  },

  -- ═══════════════════════════════════════════════════════════════════════════
  -- HIGHLIGHTING CONFIGURATION
  -- ═══════════════════════════════════════════════════════════════════════════
  highlight = {
    -- Open shot header highlighting
    open_shot = {
      fg = '#000000',  -- Foreground color (black)
      bg = '#ffb347',  -- Background color (light orange)
      bold = true,     -- Bold text
    },
  },

  -- ═══════════════════════════════════════════════════════════════════════════
  -- PATTERN CONFIGURATION
  -- ═══════════════════════════════════════════════════════════════════════════
  patterns = {
    -- Shot header pattern (matches both open and executed)
    shot_header = '^##%s+x?%s*shot',

    -- Open shot header pattern (not marked with x)
    open_shot_header = '^##%s+shot',

    -- Executed shot header pattern (marked with x)
    executed_shot_header = '^##%s+x%s+shot',

    -- Image reference pattern
    image_ref = '^img(%d+):',
  },

  -- ═══════════════════════════════════════════════════════════════════════════
  -- FEATURE FLAGS
  -- ═══════════════════════════════════════════════════════════════════════════
  features = {
    -- Enable queue system
    queue_enabled = true,

    -- Enable context injection
    context_enabled = true,

    -- Enable image insertion
    images_enabled = true,

    -- Enable PRD integration
    prd_enabled = true,
  },

  -- ═══════════════════════════════════════════════════════════════════════════
  -- SOUND CONFIGURATION
  -- ═══════════════════════════════════════════════════════════════════════════
  sound = {
    -- Enable sound notification on shot sent
    enabled = false,

    -- Sound file path (macOS: afplay, Linux: paplay)
    file = '/System/Library/Sounds/Pop.aiff',

    -- Volume (0.0 to 1.0)
    volume = 0.5,
  },

  -- ═══════════════════════════════════════════════════════════════════════════
  -- REPOSITORY CONFIGURATION (for cross-repo features)
  -- ═══════════════════════════════════════════════════════════════════════════
  repos = {
    -- Directories to search for git repos
    search_dirs = {},  -- e.g., {'~/cod', '~/projects'}

    -- Direct paths to git repos
    direct_paths = {},  -- e.g., {'~/my-special-repo'}
  },

  -- ═══════════════════════════════════════════════════════════════════════════
  -- INBOX CONFIGURATION (for task import feature)
  -- ═══════════════════════════════════════════════════════════════════════════
  inbox = {
    -- Directories containing markdown inbox files
    search_dirs = {},  -- e.g., {'~/art/me/inbox'}

    -- Direct paths to markdown inbox files
    direct_paths = {},  -- e.g., {'~/art/me/me.md'}
  },

  -- ═══════════════════════════════════════════════════════════════════════════
  -- PROJECT PICKER CONFIGURATION
  -- ═══════════════════════════════════════════════════════════════════════════
  projects = {
    -- Folder names to exclude from project picker
    exclude_folders = { '_archive', '_template' },
  },
})
```

### Highlight Customization

The open shot highlighting (black on light orange by default) is configurable:

```lua
-- Example: Yellow background (original style, may conflict with search highlights)
highlight = {
  open_shot = {
    fg = '#000000',
    bg = '#ffff00',
    bold = true,
  },
}

-- Example: White on blue
highlight = {
  open_shot = {
    fg = '#ffffff',
    bg = '#0066cc',
    bold = false,
  },
}
```

## Context Files

Shooter.nvim injects context when sending shots to AI:

1. **Global Context** (`~/.config/shooter.nvim/shooter-context-global.md`)
   - Shared across all projects
   - Your coding preferences, conventions, etc.

2. **Project Context** (`.shooter.nvim/shooter-context-project.md` at git root)
   - Project-specific instructions
   - Auto-created from template on first use

## Template System

Shooter uses customizable templates for the context instructions sent with each shot.

### Template Locations (Priority Order)

1. **Project-specific**: `./.shooter.nvim/shooter-context-instructions.md`
2. **Global**: `~/.config/shooter.nvim/shooter-context-instructions.md`
3. **Plugin fallback**: Built-in templates

For multi-shot sends, use `shooter-context-instructions-multishot.md`.

### Template Variables

Use `{{variable_name}}` syntax in your templates:

| Variable | Description | Example |
|----------|-------------|---------|
| `{{shot_num}}` | Current shot number | `117` |
| `{{shot_nums}}` | Comma-separated (multishot) | `1, 2, 3` |
| `{{file_path}}` | File path (with ~ for home) | `~/dev/plans/prompts/file.md` |
| `{{file_name}}` | Filename with extension | `20260118_0516_feature.md` |
| `{{file_title}}` | Title from first # heading | `2026-01-18 - feature name` |
| `{{repo_name}}` | Repository name from git | `divramod/shooter.nvim` |
| `{{repo_path}}` | Git root path (with ~) | `~/cod/shooter.nvim` |

### Example Custom Template

Create `~/.config/shooter.nvim/shooter-context-instructions.md`:

```markdown
# context
1. This is shot {{shot_num}} of "{{file_title}}" in {{repo_name}}.
2. Please read {{file_path}} for previous context.
3. You should not implement old shots.
4. Your current task is shot {{shot_num}}.
```

See `templates/VARIABLES.md` for full documentation

## File Structure

```
plans/prompts/
├── 20260121_0930_add-auth.md          # In-progress
├── archive/
│   └── 20260120_1015_setup-db.md      # Completed
├── backlog/
│   └── 20260122_0800_refactor-api.md  # Future work
├── done/
│   └── 20260119_1400_init-project.md  # Finished
└── .shot-queue.json                    # Queue state
```

## Project Support

For mono-repos with multiple projects, shooter.nvim supports a `projects/` folder structure:

```
repo/
├── plans/prompts/              # Root-level prompts
│   └── shared-feature.md
└── projects/
    ├── frontend/
    │   └── plans/prompts/      # Frontend project prompts
    │       └── add-login.md
    └── backend/
        └── plans/prompts/      # Backend project prompts
            └── api-routes.md
```

### How It Works

When a `projects/` folder exists at git root:

1. **Auto-detection**: If your cwd is inside `projects/<name>/`, that project is automatically used
2. **Project picker**: If at repo root, `<space>n` and `<space>v` show a project picker first
3. **Root option**: The picker includes "(root)" to create files at `plans/prompts/` instead
4. **History paths**: Shot history includes project: `~/.config/.../history/user/repo/project/filename/`
5. **Dashboard**: Shows files from all projects with project prefix (e.g., `frontend/add-login.md`)
6. **All Repos picker**: `<space>T` includes files from all projects across all repos

### Project-Aware Commands

| Command | Behavior with projects/ |
|---------|------------------------|
| `<space>n` | Project picker if at root, auto-detect if inside project |
| `<space>v` | Same - picker or auto-detect |
| `<space>o` | Works with current file (no change) |
| Movement | Moves within same project's folder structure |
| Dashboard | Shows all files with project prefix |

### Backward Compatibility

Repos without a `projects/` folder work exactly as before - all commands create/list files at `plans/prompts/`.

## Shot Format

Shots are ordered with the **latest at the top**:

```markdown
# 2026-01-21 - Feature Title

## shot 3
Next task to work on

## x shot 2 (2026-01-21 14:30:00)
Completed shot (marked with 'x' and timestamp)

## x shot 1 (2026-01-21 10:00:00)
First task (already done)
```

## Health Check

```
:checkhealth shooter
```

Validates:
- Neovim plugin dependencies (Telescope, oil.nvim, vim-i3wm-tmux-navigator)
- System dependencies (tmux, python, ttok)
- Context files
- Directory structure
- Queue file integrity

## Sound Notifications

Shooter can play a sound when a shot is successfully sent. This is useful for audible feedback when you're not looking at the screen.

**Configuration:**
```lua
sound = {
  enabled = true,  -- Enable/disable sound
  file = '/System/Library/Sounds/Pop.aiff',  -- Sound file path
  volume = 0.5,  -- Volume (0.0-1.0)
}
```

**Available macOS system sounds** (in `/System/Library/Sounds/`):
- `Pop.aiff` (default) - short pop
- `Glass.aiff` - glass clink
- `Ping.aiff` - ping
- `Tink.aiff` - light tap
- `Blow.aiff`, `Bottle.aiff`, `Frog.aiff`, `Funk.aiff`, `Morse.aiff`, `Purr.aiff`, `Sosumi.aiff`, `Submarine.aiff`

**Custom sound:** Use any `.aiff`, `.mp3`, or `.wav` file:
```lua
sound = {
  enabled = true,
  file = '~/.config/shooter.nvim/shot.mp3',
  volume = 0.7,
}
```

**Test sound:** Run `:ShooterSoundTest` to test your configuration.

**Linux:** Uses `paplay` (PulseAudio) instead of `afplay`.

## Tips

1. **Multi-select shots**: In `:ShooterOpenShots`, press `Tab` to select multiple, then `1-4` to send all
2. **Context management**: Edit `~/.config/shooter.nvim/shooter-context-global.md` to customize AI instructions
3. **Queue workflow**: Queue shots while waiting for AI response, then send batch later
4. **Oil integration**: Works seamlessly with [oil.nvim](https://github.com/stevearc/oil.nvim) for file management
5. **File-based sending**: Shots are sent via `@filepath` syntax for reliability. The shot history file is saved to `~/.config/shooter.nvim/history/<user>/<repo>/<filename>/shot-NNNN-<timestamp>.md`. Note: This won't show blue like typed input in Claude Code, but Claude outputs the content at the start of each response for transparency.
6. **Sound notifications**: Enable `sound.enabled = true` to hear a sound when shots are sent

## Troubleshooting

### Shot marked as sent but wasn't actually sent

If a shot was marked as sent (header changed from `## shot N` to `## x shot N (timestamp)`) but the send failed due to a problem (e.g., tmux issue, Claude not responding), you have two options to undo the marking:

1. **Native vim undo**: Press `u` in vim immediately after the marking happened. This will undo the header change like any other edit.

2. **Undo latest sent command**: Press `<space>u` (or `:ShooterUndoLatestSent`) to automatically find and undo the marking of the most recently sent shot. This is useful if you've made other edits since the marking and can't use native undo. The command:
   - Finds the shot with the most recent timestamp
   - Changes `## x shot N (YYYY-MM-DD HH:MM:SS)` back to `## shot N`
   - Saves the file
   - Moves cursor to the undone shot

## License

MIT

## Credits

Refactored from [divramod's dotfiles](https://github.com/divramod/dotfiles) next-action workflow.
