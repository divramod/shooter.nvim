# Shooter.nvim Plugin Refactoring Plan

## Overview
Refactor the next-action functionality from dotfiles into a standalone, publishable Neovim plugin called `shooter.nvim`.

**Critical Constraints:**
- **200 line maximum per file** (shots 104, 106)
- Replace existing code immediately (no parallel setup)
- Maintain 100% functionality from current implementation
- All files must have plenary.nvim tests (100% coverage goal)
- Location: `~/cod/shooter.nvim/` with symlink to nvim config

## Current Code Analysis

### Files to Refactor
1. **next-action.lua** (1930 lines) - Core functionality
2. **tmux-send.lua** (624 lines) - Send to Claude via tmux
3. **shot-queue.lua** (218 lines) - Queue management
4. **Context files** - Need relocation to new paths

### Key Features (must preserve all)
- 25+ commands (DmNextAction*)
- 30+ keybindings (<space> prefix)
- Telescope pickers with previews and multi-select
- Tmux integration (send to panes 1-9)
- Queue system with JSON persistence
- Context file injection (general + project)
- File movement (archive/backlog/done/reqs/test/wait/prompts/git-root)
- Shot tracking (mark as executed with timestamp)
- Image insertion via `hal`
- PRD task list integration
- Help system

## Plugin Directory Structure

```
~/cod/shooter.nvim/
├── lua/
│   └── shooter/
│       ├── init.lua                  # Main setup function (< 200 lines)
│       ├── config.lua                # Configuration defaults (< 200 lines)
│       ├── health.lua                # :checkhealth integration (< 200 lines)
│       ├── core/
│       │   ├── files.lua             # File operations (< 200 lines)
│       │   ├── shots.lua             # Shot detection/marking (< 200 lines)
│       │   ├── movement.lua          # Move files between folders (< 200 lines)
│       │   └── context.lua           # Context file management (< 200 lines)
│       ├── telescope/
│       │   ├── pickers.lua           # Telescope picker constructors (< 200 lines)
│       │   ├── actions.lua           # Telescope action handlers (< 200 lines)
│       │   └── previewers.lua        # Custom previewers (< 200 lines)
│       ├── tmux/
│       │   ├── send.lua              # Send text to tmux panes (< 200 lines)
│       │   ├── detect.lua            # Find Claude panes (< 200 lines)
│       │   └── messages.lua          # Build shot messages (< 200 lines)
│       ├── queue/
│       │   ├── init.lua              # Queue management (< 200 lines)
│       │   ├── storage.lua           # JSON persistence (< 200 lines)
│       │   └── picker.lua            # Queue telescope picker (< 200 lines)
│       ├── commands.lua              # Register all commands (< 200 lines)
│       ├── keymaps.lua               # Default keybindings (< 200 lines)
│       └── utils.lua                 # Shared utilities (< 200 lines)
├── templates/
│   ├── shooter-context-project-template.md
│   └── shooter-context-message.md
├── plugin/
│   └── shooter.lua                   # Auto-load commands (< 200 lines)
├── doc/
│   └── shooter.txt                   # Vim help documentation
├── tests/
│   ├── minimal_init.lua              # Test environment setup
│   ├── core/
│   │   ├── files_spec.lua
│   │   ├── shots_spec.lua
│   │   ├── movement_spec.lua
│   │   └── context_spec.lua
│   ├── telescope/
│   │   ├── pickers_spec.lua
│   │   ├── actions_spec.lua
│   │   └── previewers_spec.lua
│   ├── tmux/
│   │   ├── send_spec.lua
│   │   ├── detect_spec.lua
│   │   └── messages_spec.lua
│   └── queue/
│       ├── init_spec.lua
│       ├── storage_spec.lua
│       └── picker_spec.lua
├── README.md                         # GitHub readme with installation
├── CLAUDE.md                         # Architecture documentation
├── LICENSE                           # MIT or your choice
└── .github/
    └── workflows/
        └── test.yml                  # CI for running tests
```

## Context File Migration

### Old Paths → New Paths
- General: `~/dev/.ai/na-context-general.md` → `~/.config/shooter.nvim/shooter-context-general.md`
- Project template: `~/dev/.ai/na-context-project-template.md` → `templates/shooter-context-project-template.md` (in plugin)
- Project: `.ai/na-context.md` → `.shooter.nvim/shooter-context-project.md` (at git root)

## Installation Examples

### lazy.nvim
```lua
{
  'divramod/shooter.nvim',
  dependencies = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('shooter').setup({
      -- Optional: override defaults
      paths = {
        general_context = '~/.config/shooter.nvim/shooter-context-general.md',
      },
    })
  end,
}
```

## Implementation Status

### ✅ Completed
- [x] Repository structure created
- [x] Context files migrated
- [x] Core modules extracted (files, shots, movement, context)
- [x] Telescope modules (pickers, actions, previewers)
- [x] Tmux modules (send, detect, messages)
- [x] Queue modules (init, storage, picker)
- [x] Top-level modules (init, config, commands, keymaps, utils, health)
- [x] Documentation (README.md, CLAUDE.md, LICENSE)
- [x] Test infrastructure (minimal_init.lua, sample test, CI workflow)
- [x] All modules under 200 lines ✓
- [x] Published to github.com:divramod/shooter.nvim

### 📋 Remaining Work (tracked in beads)
- [ ] Write comprehensive plenary tests (dev-o7l)
- [ ] Integrate into nvim config (dev-x4h)
- [ ] Create vim help documentation (dev-2rb)
- [ ] Remove old next-action files from dotfiles
- [ ] Remove old keybindings from n-special.lua

## Key Architectural Decisions

1. **Modular design:** Strict 200-line limit enforces single responsibility
2. **Lazy loading:** Commands and keys-based loading for performance
3. **Plenary tests:** Industry standard for Neovim plugins
4. **Health checks:** Built-in dependency validation
5. **Template system:** Customizable message and context templates
6. **Config merging:** User can override any default
7. **Backward compatible:** Keep all existing functionality
8. **Git-based:** Publishable on GitHub, installable via URL

## Timeline

- **Shot 104 (2026-01-21):** Complete refactoring ✓
  - Created all 24 modules
  - Set up testing infrastructure
  - Published to GitHub
  - Committed: fd4c7a8, dd9e783

## Success Criteria

✅ All existing functionality preserved
✅ Every file < 200 lines
✅ Published on GitHub
✅ Installable via plugin managers
✅ Clear documentation (README, CLAUDE.md)
⏳ 100% test coverage with plenary (in progress)
⏳ Works with lazy.nvim integration (testing)
⏳ Health checks validate dependencies (implemented, testing)
⏳ Vim help documentation (todo)

## References

- Original implementation: `~/dev/dotfiles/nvim-divramod/lua/functions/next-action.lua`
- Repository: https://github.com/divramod/shooter.nvim
- Beads issues: dev-o7l, dev-x4h, dev-2rb
