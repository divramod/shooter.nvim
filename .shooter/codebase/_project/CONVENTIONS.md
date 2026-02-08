# Coding Conventions

**Analysis Date:** 2026-02-08

## Naming Patterns

**Files:**
- Module files use snake_case: `shot_normalize.lua`, `shot_actions.lua`, `shot_delete.lua`
- Test files use snake_case with `_spec.lua` suffix: `shots_spec.lua`, `project_spec.lua`, `rename_spec.lua`
- Directory names use snake_case: `lua/shooter/core/`, `lua/shooter/tools/`, `tests/tmux/`
- Subdirectory modules: `response_viewer/claude.lua`, `response_viewer/opencode.lua`

**Functions:**
- All functions use snake_case: `find_current_shot()`, `mark_shot_executed()`, `get_git_root()`, `is_telescope_picker()`
- Private/local functions prefixed with underscore: `local function _is_in_code_block()` (no underscore prefix used; instead marked with `local` keyword)
- Public functions exported via module table: `function M.function_name()`
- Functions with side effects are explicit: `apply_syntax()`, `setup()`, `notify()`

**Variables:**
- Local variables use snake_case: `shot_start`, `shot_end`, `bufnr`, `filepath`, `git_root`
- Constants use UPPERCASE: Not consistently used; configuration values stored in config module
- Boolean variables can use `is_` prefix: `is_executed`, `is_telescope_picker()`, `is_shotfile()`
- Table/collection variables often plural: `lines`, `shots`, `files`, `results`

**Types:**
- No explicit type annotations (Lua is dynamically typed)
- Tables use camelCase for named keys when representing structs: `{ name = name, path = path }`, `{ value = value, path = path }`
- Array-like tables use numeric indices: `table.insert(results, item)`

## Code Style

**Formatting:**
- No explicit formatter detected (no `.prettierrc`, `stylua`, or `biome.json`)
- Two-space indentation observed throughout codebase
- Maximum line length: ~100 characters (observed in most files)
- Blank lines between function definitions for readability

**Linting:**
- No explicit linter configuration detected (no `.luacheckrc` or similar)
- Code follows standard Lua conventions
- Shell commands and vim API calls are quoted: `'git rev-parse --show-toplevel'`, `vim.fn.fnamemodify()`

**Spacing:**
- Single space after control keywords: `if condition then`, `for i = 1, n do`
- No space before parentheses in function calls: `require('shooter.utils')`
- Space around binary operators: `i = 1`, `not is_block`

## Import Organization

**Order:**
1. Module comments (describe purpose)
2. Required modules (local imports)
3. Module table initialization (`local M = {}`)
4. Function definitions (public then private)
5. Return statement (`return M`)

**Example pattern:**
```lua
-- Comment describing module purpose
local utils = require('shooter.utils')
local config = require('shooter.config')

local M = {}

-- Function definitions...

function M.public_function()
  -- implementation
end

local function private_helper()
  -- implementation
end

return M
```

**Path Aliases:**
- No aliases detected; uses relative module paths: `require('shooter.core.shots')`
- Modules imported as needed (lazy loading used for submodules)

## Error Handling

**Patterns:**
- **Early returns**: Functions return early with nil/false on error: `if not file then return nil, "error message" end`
- **Tuple returns**: Functions return `(success, error_message, extra_data)`: `return false, 'Invalid parameters'` or `return true, nil, { new_path = new_path }`
- **vim.notify() for user-facing errors**: `vim.notify('Not in a git repository', vim.log.levels.WARN)`
- **vim.v.shell_error for system commands**: Check `vim.v.shell_error == 0` after system operations
- **pcall for optional dependencies**: `local ok, oil = pcall(require, 'oil')` then check `if ok then`
- **Exception-free approach**: No explicit try-catch; uses defensive checks

**Common patterns:**
```lua
-- Safe file operations
local file = io.open(path, 'r')
if not file then
  return nil, string.format("Could not read file: %s", path)
end
local content = file:read('*a')
file:close()
return content, nil

-- Optional dependency check
local ok, module = pcall(require, 'optional-module')
if ok then
  local entry = module.get_something()
  if entry then
    -- use entry
  end
else
  return nil  -- fallback
end

-- System command error check
local result = vim.fn.systemlist('git command')
if vim.v.shell_error == 0 and #result > 0 then
  return result[1]
end
return nil
```

## Logging

**Framework:** `vim.notify()` for all user notifications

**Patterns:**
- `vim.notify(msg, vim.log.levels.INFO)` - informational
- `vim.notify(msg, vim.log.levels.WARN)` - warnings
- `vim.notify(msg, vim.log.levels.ERROR)` - errors
- `vim.log.levels.DEBUG` - not used in codebase
- `utils.echo(msg)` - command-line echo without requiring Enter
- `utils.echo_regular(msg)` - regular echo (may require Enter)

**When to log:**
- User-triggered failures: "Not in a git repository", "File already exists"
- Important state changes: "shot marked executed", "file renamed"
- Warning conditions: "Optional dependency not available"
- Debug: Not used; should log via tests instead

## Comments

**When to Comment:**
- **Module header**: Every module starts with a comment describing its purpose and what it does
- **Complex logic**: Explain *why* not *what* (code shows what)
- **Non-obvious patterns**: Explain code block boundaries (especially for state machines)
- **Important assumptions**: Preconditions for functions with constraints

**JSDoc/TSDoc:**
- Not used; this is Lua, not TypeScript
- Function comments use simple format:
```lua
-- Get timestamp in YYYY-MM-DD HH:MM:SS format
-- @return string timestamp
function M.get_timestamp()

-- Perform the actual rename operation
-- @param old_path: Full path to current file
-- @param new_filename: New filename (just the name, not path)
-- @return success, error_message
function M.perform_rename(old_path, new_filename)
```

**Comment style:**
- Double-dash `--` for single-line comments
- Comments on same line as code: `if not shot_start then return nil end -- No shot found`
- Section separators: Comment lines with repeated dashes for visual grouping (not used)

## Function Design

**Size:**
- Most functions are 5-30 lines
- Larger functions (50+ lines) are broken into logical helpers
- Example: `M.normalize_shot()` at ~50 lines combines multiple operations but is cohesive

**Parameters:**
- Functions accept bufnr with default: `function M.find_current_shot(bufnr, cursor_line)`
  - `bufnr = bufnr or 0` (0 = current buffer)
  - `cursor_line = cursor_line or utils.get_cursor()[1]`
- Optional parameters with defaults: `M.count_tokens(filepath)` with nil checks
- No rest parameters or varargs; explicit parameter lists

**Return Values:**
- Most functions return single value: `return project_name` or `return lines`
- Error-handling functions return tuple: `success, error_message` or `success, error_message, extra_data`
- Nil represents missing/not found: `return nil` instead of empty string or false
- Booleans for predicates: `is_telescope_picker()` returns true/false
- Tables for collections: `list_projects()` returns `{}`

## Module Design

**Exports:**
- All public functions prefixed with `M.`: `function M.setup(user_config)`
- Module table exposed at end: `return M`
- Private functions marked with `local function` keyword
- No protected/private naming convention; just use `local`

**Barrel Files:**
- Used for lazy loading: `lua/shooter/tmux/init.lua` re-exports submodules:
```lua
M.detect = require('shooter.tmux.detect')
M.send = require('shooter.tmux.send')
```
- Allows `local tmux = require('shooter.tmux')` then `tmux.detect.something()`

**Module Initialization:**
- Most modules have no initialization; functions called directly
- `M.setup()` used for modules that configure state: `M.setup(user_config)`
- Configuration module uses `config.get('path.to.key')` for runtime access

---

*Convention analysis: 2026-02-08*
