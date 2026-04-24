# Coding Conventions

**Analysis Date:** 2026-04-03

## Naming Patterns

**Files:**
- Use `snake_case.lua` for all Lua source files: `shot_delete.lua`, `filter_state.lua`, `ext_config.lua`
- Test files mirror source structure with `_spec.lua` suffix: `shots_spec.lua`, `rename_spec.lua`
- Module entry points use `init.lua` within a directory: `lua/shooter/tmux/init.lua`, `lua/shooter/providers/init.lua`

**Functions:**
- Use `snake_case` for all function names: `find_current_shot`, `mark_shot_executed`, `get_next_shot_number`
- Prefix private/local functions with `local function`: `local function is_in_code_block(lines, line_num)`
- Module functions are declared on `M`: `function M.play()`, `function M.setup()`

**Variables:**
- Use `snake_case` for all variables: `shot_start`, `header_line`, `total_lines`
- Constants use `UPPER_CASE` only for module-level defaults tables: `M.DEFAULTS` in `lua/shooter/core/ext_config.lua`
- Boolean variables use descriptive names: `is_executed`, `header_updated`, `echo_called`

**Types/Tables:**
- Module tables are always `local M = {}` returned at end of file
- Provider identity fields use `snake_case`: `M.name`, `M.display_name`, `M.process_pattern`

## Code Style

**Formatting:**
- No formatter configuration detected (no `.stylua.toml`, `.luacheckrc`, or `.editorconfig`)
- Indent with 2 spaces consistently across all files
- Single quotes for strings: `'shooter.core.shots'`, `'disabled'`
- No trailing commas required in table literals (mixed usage observed)

**Linting:**
- luacheck runs optionally in CI (`.github/workflows/test.yml` line 48-54) with `continue-on-error: true`
- No local luacheck config file detected

## Module Pattern

**Every Lua module follows this exact structure:**

```lua
-- Module description comment
-- Additional context line

local M = {}

-- Local requires at top
local utils = require('shooter.utils')
local config = require('shooter.config')

-- Local helper functions (not exported)
local function helper_fn(arg)
  -- ...
end

-- Public functions on M
function M.public_fn(arg)
  -- ...
end

return M
```

**Key rules:**
- Always `local M = {}` at top, `return M` at bottom
- Local requires grouped at top of file, after module table declaration
- Some modules use lazy loading via inline `require()` calls within functions (see `lua/shooter/tmux/init.lua` lines 37-40)
- Provider modules set identity fields directly on `M`: `M.name = 'claude'`

## Import Organization

**Order:**
1. Local module table: `local M = {}`
2. Requires from within the plugin: `local utils = require('shooter.utils')`
3. No external library imports (all Neovim API access is via `vim.*`)

**Path Conventions:**
- All requires use dot-separated paths: `require('shooter.core.shots')`
- Plugin root is `shooter`: `require('shooter.utils')`, `require('shooter.config')`
- Submodule paths mirror directory structure exactly

## Error Handling

**Patterns:**
- Return `nil` or `false` for failure, with optional error string: `return nil, nil, nil` or `return false, "already exists"`
- Use `pcall` for JSON decode and other potentially failing operations:
  ```lua
  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= 'table' then
    return { current = {}, sessions = {} }
  end
  ```
- Guard clauses with early returns for invalid state:
  ```lua
  if not shot_start then
    return nil, nil, nil
  end
  ```
- User-facing errors use `vim.notify()` with level:
  ```lua
  vim.notify('shooter.nvim is already initialized', vim.log.levels.WARN)
  ```
- Inline errors use `utils.echo()` for command-line messages:
  ```lua
  utils.echo('Not in a shooter file')
  ```

**Three-return pattern** for operations: `success_bool, error_string, info_table`
- Example from `lua/shooter/core/rename.lua`: `local success, err, info = rename.perform_rename(filepath, 'new-file.md')`

## Logging

**Framework:** Neovim built-in `vim.notify` and custom `utils.echo`

**Patterns:**
- Use `utils.echo(msg)` for transient command-line messages (does not require Enter press)
- Use `utils.notify(msg, level)` for persistent notification messages
- Use `vim.notify(msg, vim.log.levels.WARN)` directly for plugin-level warnings
- Silent failure for non-critical operations (e.g., sound playback in `lua/shooter/sound.lua` line 42)

## Comments

**When to Comment:**
- Module-level doc comment on first two lines describing purpose:
  ```lua
  -- Shot detection and management for shooter.nvim
  -- Finding, marking, and parsing shots in shooter files
  ```
- Inline comments for non-obvious logic or pattern matching
- Section separators using `-- ====...` in `lua/shooter/keymaps.lua` for keymap groups

**JSDoc/TSDoc:**
- Not used. Lua does not have JSDoc conventions in this codebase.
- Function purpose documented via preceding comments when needed

## Function Design

**Size:** Functions are generally small (5-30 lines). Larger functions exist in `lua/shooter/commands.lua` for command registration.

**Parameters:**
- Optional parameters default via `or`: `bufnr = bufnr or 0`, `pane_index = pane_index or 1`
- Config values accessed via `config.get('path.to.value')` pattern
- Tables used for complex configuration: `{ noremap = true, silent = true }`

**Return Values:**
- Single value for simple queries: `return max_shot + 1`
- Multiple returns for operations with possible failure: `return success, err, info`
- Tables for collections: `return shots` (array of shot info tables)
- `nil` for "not found" cases

## Module Design

**Exports:** Only functions and submodule references on `M` table are public API.

**Barrel Files:** `init.lua` files serve as barrel/facade modules:
- `lua/shooter/tmux/init.lua` re-exports submodule references and wraps operations
- `lua/shooter/providers/init.lua` manages provider registry and exposes detection API

**Submodule Access:** Parent modules expose child modules as table fields:
```lua
M.detect = require('shooter.tmux.detect')
M.send = require('shooter.tmux.send')
```

## Command Registration

**Pattern:** All Vim commands are registered in `lua/shooter/commands.lua` using `vim.api.nvim_create_user_command`. Commands use `Sho` prefix namespace:
- `ShoShotfileNew`, `ShoShotSend`, `ShoShotPicker`, etc.
- Optional backward-compat aliases via `create_cmd(name, fn, opts, alias)` helper

**Guard pattern** for shotfile-only commands:
```lua
local function require_shotfile(fn)
  return function(opts)
    local files = require('shooter.core.files')
    if not files.is_shooter_file() then
      vim.notify('This command only works in shotfiles', vim.log.levels.WARN)
      return
    end
    fn(opts)
  end
end
```

## Configuration Access

**Two config systems coexist:**

1. **Lua config** (`lua/shooter/config.lua`): In-memory config merged from defaults + user `setup()` call. Access via `config.get('tmux.delay')` and `config.set('path', value)`.

2. **External YAML config** (`lua/shooter/core/ext_config.lua`): File-based config from `~/.config/hal/util/shooter/nvim/config.yaml` and `.hal/util/shooter/cfg/nvim/config.yaml`. Access via `ext_config.get('file.open_shots.color_bg')`.

Both use dot-path accessors. Lua config is for plugin behavior; ext_config is for user-facing settings (colors, preferences).

---

*Convention analysis: 2026-04-03*
