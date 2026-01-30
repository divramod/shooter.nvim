# Coding Conventions

**Analysis Date:** 2026-01-30

## Naming Patterns

**Files:**
- Snake_case with underscores: `shot_delete.lua`, `clipboard_image.lua`, `token_counter.lua`
- Directories use snake_case: `core/`, `tmux/`, `telescope/`, `context/`, `session/`
- Test files append `_spec.lua`: `shots_spec.lua`, `project_spec.lua`, `shell_spec.lua`

**Functions:**
- Snake_case for all function names: `find_current_shot()`, `mark_shot_executed()`, `get_git_root()`
- Private helper functions prefixed with underscore: `local function is_in_code_block()`, `local function get_day_start()`
- Exported functions (in module M) follow snake_case without prefix: `M.find_all_shots()`, `M.get_shot_content()`

**Variables:**
- Snake_case: `shot_start`, `shot_end`, `header_line`, `current_title`, `new_filename`
- Descriptive names describing what is held: `bufnr` (buffer number), `filepath` (full path), `shot_info` (shot information table)
- Loop counters: `i`, `j` for numeric loops; `_, value` when unpacking tables

**Types/Tables:**
- Tables returned with descriptive field names: `{ start_line = X, end_line = Y, header_line = Z, is_executed = bool }`
- Config table keys use dot notation in string keys: `config.get('patterns.shot_header')`, `config.get('paths.prompts_root')`
- Namespaced constants via table structure: `M.persistent_state`, `M._initialized`, `M._config`

## Code Style

**Formatting:**
- Lua standard indentation (no configuration file enforced; uses standard 2-space indentation)
- Lines can exceed typical limits (seen up to 100+ characters)
- Function documentation in comments above function definition
- Comments are concise and describe the "why"

**Module Structure:**
- Every module starts with `local M = {}` to define exports
- Module ends with `return M` to export the public API
- Private functions defined with `local function` prefix
- Public functions attached to M: `function M.my_function() end`

**Patterns:**
- Guards at function start: `if not condition then return end`
- Use of default parameters: `bufnr = bufnr or 0`, `level = level or vim.log.levels.INFO`
- Safe require with pcall for optional dependencies: `local ok, oil = pcall(require, 'oil')` followed by `if ok then ... end`

## Import Organization

**Order:**
1. Comment header describing module purpose
2. Local module imports (require calls)
3. Module initialization (`local M = {}`)
4. Helper function definitions (private functions)
5. Exported functions (attached to M)
6. Return statement (`return M`)

**Example from `shots.lua`:**
```lua
-- Shot detection and management for shooter.nvim
-- Finding, marking, and parsing shots in shooter files

local utils = require('shooter.utils')
local config = require('shooter.config')

local M = {}

-- Check if a line is inside a code block (count ``` markers above)
local function is_in_code_block(lines, line_num) ... end

function M.find_current_shot(bufnr, cursor_line) ... end
```

**Path Aliases:**
- None detected in codebase; uses direct relative requires: `require('shooter.utils')`, `require('shooter.core.shots')`
- Absolute paths from plugin root (lua/shooter/)

## Error Handling

**Patterns:**
- Return tuple pattern: `(success, error_msg)` or `(result, error_msg, extra_info)` - see `rename.lua:perform_rename()`
- Nil returns for missing data: `function M.find_current_shot()` returns `nil, nil, nil` when no shot found
- System error checking: `if vim.v.shell_error == 0 and #result > 0 then` after `systemlist()` calls
- File operation guards: Check file existence before reading: `if not file then return nil, msg end`
- Optional dependency handling via pcall: `local ok, oil = pcall(require, 'oil')` to safely load optional modules

**User Notifications:**
- Non-critical messages via `utils.echo()` (shows in command line)
- Important messages via `utils.notify()` with log level: `vim.log.levels.WARN`, `vim.log.levels.ERROR`, `vim.log.levels.INFO`
- Errors in callbacks use notify: `utils.notify('File already exists: ' .. new_filename, vim.log.levels.ERROR)`

## Logging

**Framework:** `vim.notify` via `utils.notify()` helper

**Patterns:**
- Log on start of operations: "No file selected", "Not in a shooter file"
- Log on completion: "Renamed to ..." with additional context
- Log errors with specific reason: "File already exists: X" not just "Error"
- Use log levels consistently:
  - `vim.log.levels.ERROR` for failures blocking operation
  - `vim.log.levels.WARN` for non-fatal issues
  - `vim.log.levels.INFO` for operational status

**No logging inside library functions** - functions like `find_current_shot()`, `get_shot_content()` return values; callers decide what to notify.

## Comments

**When to Comment:**
- Above functions: Describe what function does, parameters, and returns
- On complex logic: Explain algorithm or non-obvious pattern matching
- CRITICAL sections: Mark areas where order/timing matters (see `rename.lua:120` - buffer must close before file rename)
- Skip obvious code: No comment needed for `if condition then return end` guards

**Style:**
- Single-line comments: `-- Comment here`
- Above function definitions for public APIs
- Inline comments on complex regex patterns or timestamps

**Example from `rename.lua`:**
```lua
-- CRITICAL: Save and close the buffer before modifying file on disk
-- This prevents content loss when Neovim's buffer state conflicts with disk state
```

## Function Design

**Size:**
- Typical range: 15-40 lines
- Larger files split by namespace (e.g., `commands.lua` at 634 lines is split across namespaces)
- Complex operations extract helpers: `is_in_code_block()` helper in `shots.lua`

**Parameters:**
- Typically 1-3 parameters
- Optional parameters use default pattern: `local arg = arg or default_value`
- Context parameters often optional: `bufnr = bufnr or 0` (0 = current buffer), `cursor_line = cursor_line or utils.get_cursor()[1]`
- No long parameter lists; complex data passed as tables

**Return Values:**
- Single return for simple getters: `return result`
- Tuple returns for operations: `return success, error_msg` or `return value, error_msg, metadata_table`
- Multiple returns separated by commas: `local start, finish, header = shots.find_current_shot(bufnr, 3)`

## Module Design

**Exports:**
- All public functions attached to M table: `function M.my_function() end`
- Private functions use `local function` and not attached to M
- Single export statement at end: `return M`

**Barrel Files:**
- Minimal barrel pattern; some aggregation in `tmux/init.lua`:
  ```lua
  M.detect = require('shooter.tmux.detect')
  M.send = require('shooter.tmux.send')
  ```
- Most modules are single-responsibility, no re-exports

**Dependency Injection:**
- Some functions receive modules as parameters for testability: `operations.send_current_shot(pane_index, M.detect, M.send, M.messages)`
- Allows mocking in tests and decouples responsibility

---

*Convention analysis: 2026-01-30*
