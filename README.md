# shooter.nvim

A Neovim plugin for managing iterative development workflows with shots (numbered work items), tmux integration, and context-aware AI collaboration.

## Features

- 📝 **Shot-based workflow**: Break down features into numbered, executable shots
- 🔄 **Tmux integration**: Send shots directly to Claude (or other AI) running in tmux panes
- 🎯 **Context injection**: Automatically includes general and project-specific context
- 📂 **File organization**: Move files between folders (archive, backlog, done, etc.)
- 🔍 **Telescope integration**: Powerful pickers for files, shots, and queues
- 📋 **Queue system**: Queue shots for later execution across multiple panes
- ✅ **Shot tracking**: Mark shots as executed with timestamps
- 🖼️ **Image insertion**: Reference images in your shots

## Requirements

- Neovim >= 0.9.0
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- tmux (for sending to AI panes)
- Claude CLI or similar AI tool (optional, for send functionality)

## Installation

### lazy.nvim

```lua
{
  'divramod/shooter.nvim',
  dependencies = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/plenary.nvim',
  },
  cmd = {
    'ShooterCreate', 'ShooterList', 'ShooterOpenShots',
    'ShooterSend1', 'ShooterSendAll1', 'ShooterQueueView',
  },
  keys = {
    { '<space>n', '<cmd>ShooterCreate<cr>', desc = 'Shooter: Create file' },
    { '<space>o', '<cmd>ShooterOpenShots<cr>', desc = 'Shooter: Open shots' },
    { '<space>t', '<cmd>ShooterList<cr>', desc = 'Shooter: List files' },
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
  },
  config = function()
    require('shooter').setup()
  end,
}
```

## Quick Start

1. **Create a new shooter file**:
   ```
   :ShooterCreate
   ```
   Enter a feature name when prompted. This creates a timestamped markdown file in `plans/prompts/`.

2. **Add shots to your file**:
   ```markdown
   # 2026-01-21 - Add user authentication

   ## shot 1
   Set up database schema for users table

   ## shot 2
   Create registration endpoint
   ```

3. **Send a shot to Claude** (in tmux):
   - Place cursor in shot 1
   - Press `<space>1` (or `:ShooterSend1`)
   - Shot content + context is sent to tmux pane running Claude

4. **View open shots**:
   ```
   :ShooterOpenShots
   ```
   - Shows all unexecuted shots in current file
   - Press `Tab` to multi-select
   - Press `1-4` to send to Claude pane

## Commands

### Core Commands

| Command | Description |
|---------|-------------|
| `:ShooterCreate` | Create new shooter file |
| `:ShooterList` | Telescope picker for all files |
| `:ShooterOpenShots` | List open shots in current file |
| `:ShooterHelp` | Show help |
| `:ShooterLast` | Open last edited file |
| `:ShooterNewShot` | Add new shot to current file |

### Send Commands

| Command | Description |
|---------|-------------|
| `:ShooterSend{1-9}` | Send current shot to pane N |
| `:ShooterSendAll{1-9}` | Send all open shots to pane N |
| `:ShooterSendVisual{1-9}` | Send visual selection to pane N |

### Queue Commands

| Command | Description |
|---------|-------------|
| `:ShooterQueueAdd{1-4}` | Add shot to queue for pane N |
| `:ShooterQueueView` | View and manage queue |
| `:ShooterQueueClear` | Clear entire queue |

### File Movement

| Command | Description |
|---------|-------------|
| `:ShooterArchive` | Move to archive/ |
| `:ShooterBacklog` | Move to backlog/ |
| `:ShooterDone` | Move to done/ |
| `:ShooterPrompts` | Move to prompts/ (in-progress) |
| `:ShooterGitRoot` | Move to git root |

## Default Keybindings

All keybindings use `<space>` prefix (customizable):

### Core

| Key | Action |
|-----|--------|
| `<space>n` | Create new file |
| `<space>o` | Open shots picker |
| `<space>t` | Telescope file list |
| `<space>l` | Open last file |
| `<space>s` | New shot |
| `<space>h` | Help |

### Send to Claude

| Key | Action |
|-----|--------|
| `<space>1-4` | Send shot to pane 1-4 |
| `<space><space>1-4` | Send ALL open shots |

### File Movement (prefix: `<space>m`)

| Key | Action |
|-----|--------|
| `<space>ma` | Archive |
| `<space>md` | Done |
| `<space>mb` | Backlog |

### Queue

| Key | Action |
|-----|--------|
| `<space>q1-4` | Queue for pane |
| `<space>Q` | View queue |

## Configuration

```lua
require('shooter').setup({
  paths = {
    -- Global context (shared across projects)
    global_context = '~/.config/shooter.nvim/shooter-context-global.md',

    -- Project context (at git root)
    project_context = '.shooter.nvim/shooter-context-project.md',

    -- Prompts directory
    prompts_root = 'plans/prompts',

    -- Queue file
    queue_file = 'plans/prompts/.shot-queue.json',
  },

  tmux = {
    delay = 0.2,  -- Delay between sends (seconds)
    max_panes = 9,  -- Max supported panes
  },

  telescope = {
    layout_strategy = 'vertical',
    layout_config = {
      width = 0.9,
      height = 0.9,
      preview_height = 0.5,
    },
  },

  keymaps = {
    enabled = true,  -- Enable default keymaps
    prefix = ' ',  -- Main prefix
    move_prefix = 'm',  -- Move command prefix
  },
})
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

## Shot Format

```markdown
# 2026-01-21 - Feature Title

## shot 1
Description of first task

## x shot 2 (20260121_1430)
Completed shot (marked with 'x' and timestamp)

## shot 3
Next task to work on
```

## Health Check

```
:checkhealth shooter
```

Validates:
- Dependencies (Telescope, tmux)
- Context files
- Directory structure
- Queue file integrity

## Tips

1. **Multi-select shots**: In `:ShooterOpenShots`, press `Tab` to select multiple, then `1-4` to send all
2. **Context management**: Edit `~/.config/shooter.nvim/shooter-context-global.md` to customize AI instructions
3. **Queue workflow**: Queue shots while waiting for AI response, then send batch later
4. **Oil integration**: Works seamlessly with [oil.nvim](https://github.com/stevearc/oil.nvim) for file management

## License

MIT

## Credits

Refactored from [divramod's dotfiles](https://github.com/divramod/dotfiles) next-action workflow.
