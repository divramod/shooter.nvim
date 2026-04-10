<!-- THIS IS A HAL PROJECT. run hal project --help to understand what it means -->
<!-- hal-version: 0.2.405 -->

## Verify Your Work

Before finishing any task:
1. Can you verify changes work? (compile, run, execute) → Do it.
2. Can you run existing tests? → Run them.
3. No tests cover your change? → Write one.
4. No way to test? → State what you couldn't verify.

# shooter.nvim

Neovim plugin for managing iterative AI development workflows through numbered "shots" (work items in markdown files) sent to AI assistants via tmux.

## Architecture

shooter.nvim is a thin Neovim wrapper around the `hal shooter` CLI. Core logic lives in `hal shooter` subcommands (JSON APIs). The Lua plugin handles UI concerns (buffers, cursors, pickers, keymaps) and delegates via `lua/shooter/hal.lua`.

### Key Layers

| Layer | Location | Responsibility |
|-------|----------|---------------|
| CLI backend | `hal shooter` (external) | Shotfile CRUD, shot operations, tmux send, sound |
| Plugin entry | `lua/shooter/init.lua` | Setup, config merge, module loading |
| Commands | `lua/shooter/commands.lua` | 50+ user commands (`HalShooter*` prefix) |
| Core | `lua/shooter/core/` | Shot parsing, file management, renumbering, movement |
| Tmux | `lua/shooter/tmux/` | Pane detection, send operations, provider routing |
| Providers | `lua/shooter/providers/` | AI provider abstraction (Claude, Codex, Copilot, Gemini, OpenCode) |
| Pickers | `lua/shooter/telescope/` | Telescope-based file/shot/queue pickers |
| Session | `lua/shooter/session/` | Non-telescope picker UI |

### Data Flow

1. User triggers command (keymap or `:HalShooter*`)
2. `commands.lua` delegates to `hal.run()` or core Lua modules
3. `hal shooter` CLI mutates files on disk, returns JSON
4. Plugin reloads buffer (`hal.reload()`) and positions cursor

### hal.lua Interface

- `hal.run(args)` — synchronous `hal shooter <args> --json`, returns `{ok, data, error}`
- `hal.run_raw(args)` — without `--json`, returns `{ok, raw, error}`
- `hal.modify(args)` — save + run + reload (for file-mutating commands)

## Module Guide

### core/

- `shots.lua` — parse shot headers, find shots by position/number
- `shot_actions.lua` — create, delete, toggle, move, yank shots (Lua-side operations)
- `files.lua` — shotfile discovery, tracking last-edited file
- `renumber.lua` — renumber + sort shots (open top, done bottom)
- `movement.lua` — move shotfiles between folders (archive, backlog, done, prompts)
- `templates.lua` — template rendering with variable substitution
- `project.lua` — monorepo/multi-project support

### tmux/

- `send.lua` — send text/file-refs to tmux panes via `hal shooter tmux send`
- `detect.lua` — detect AI panes by tmux variables and process patterns
- `operations.lua` — high-level: send current shot, send all, send visual
- `messages.lua` — format shot content with context injection
- `create.lua` — create new tmux panes for AI sessions

### providers/

Registry-based abstraction. Each provider implements:
- `name`, `display_name`, `process_pattern`
- `send_file_reference(pane_id, filepath)`
- `send_text(pane_id, text)`

Detection: tmux pane variable `@shooter_provider` or process name matching.

## Testing

- Framework: **Plenary** (Neovim test framework)
- Run: `nvim --headless -c "lua require('plenary.test_harness').test_directory('tests/', {minimal_init='tests/minimal_init.lua', sequential=true})"`
- CI: GitHub Actions, Neovim stable + nightly
- Test files: `tests/**/*_spec.lua`

### Writing Tests

- Use `tests/minimal_init.lua` for clean environment
- Test shots parsing in `tests/core/shots_spec.lua` (reference pattern)
- Mock tmux operations; test Lua logic directly

## Configuration

Entry: `require('shooter').setup({...})` merges user config with defaults in `config.lua`.

Key config sections: `paths`, `tmux`, `telescope`, `keymaps`, `highlighting`, `patterns`, `features`, `sound`, `repositories`, `projects`.

## Patterns and Conventions

### Command Naming

All commands use `HalShooter` prefix with namespace grouping:
- `HalShooterShotfile*` — shotfile operations (new, delete, rename, pick, move)
- `HalShooterShot*` — shot operations (new, delete, toggle, send, navigate)
- `HalShooterTmux*` — tmux pane operations
- `HalShooterFile*` — file-level operations (stats, coloring)

### Keymap Prefix

Default prefix: `<space>`. Examples:
- `<space>n` — new shot
- `<space>N` — new shotfile
- `<space>1`-`<space>9` — send shot to pane N
- `<space>.` — toggle shot done

### Shot Header Format

```markdown
## shot 5                              # open shot
## x shot 4 (2026-04-06 12:00:00)     # done shot with timestamp
```

### Shotfile Structure

```
.hal/shooter/shotfiles/<name>.md
```

Each file has a `# title` header followed by shots in reverse-number order (highest = newest at top).

## Dependencies

- Neovim >= 0.9.0
- telescope.nvim + plenary.nvim
- tmux (system)
- hal CLI (system, for `hal shooter` commands)
