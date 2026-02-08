# Lua Conventions

Lua-specific coding standards and best practices.

## Variables and Scope

- Use `local` for all variables by default — global pollution is the top Lua mistake
- Declare variables at the narrowest scope possible
- Use `local` for functions too: `local function foo() end`
- Avoid `_G` modifications except for intentional global registration

## Modules

- Modules return a table of public functions and values
- One module per file
- Use the module pattern:
  ```lua
  local M = {}
  function M.greet(name) return "hello " .. name end
  return M
  ```
- Never use the deprecated `module()` function

## Tables

- Use tables as the primary data structure (arrays, maps, objects)
- Use `#t` for array length only on sequence tables (no gaps)
- Prefer `ipairs` for array iteration, `pairs` for map iteration
- Initialize tables with constructors: `{ x = 1, y = 2 }`

## Strings

- Prefer string methods over patterns when the task is simple
- Use `string.format` for complex string building
- Use `[[long strings]]` for multi-line text
- Be aware: Lua strings are 1-indexed

## Error Handling

- Use `pcall`/`xpcall` for protected calls at boundaries
- Return `nil, error_message` for expected failures (Lua convention)
- Use `error()` for programmer errors (unexpected states)
- Always check return values from functions that can fail

## Performance

- Cache frequently accessed global functions locally: `local insert = table.insert`
- Avoid creating tables in hot loops — reuse when possible
- Use `table.concat` over repeated `..` for string building
- Pre-allocate tables with `table.create(n)` in Luau when size is known (Luau-specific, not standard Lua/LuaJIT)

## Tooling

- Use StyLua for formatting
- Use LuaCheck for linting and static analysis
- Use Busted or LuaUnit for testing
- Specify Lua version (5.1, 5.4, LuaJIT, Luau) in project config

## Style

- Use `snake_case` for variables and functions
- Use `PascalCase` for classes/constructors
- Use `UPPER_SNAKE` for constants
- Two-space or four-space indentation (be consistent within project)
- Prefer early returns to reduce nesting
