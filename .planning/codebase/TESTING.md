# Testing Patterns

**Analysis Date:** 2026-01-30

## Test Framework

**Runner:**
- plenary.nvim (Lua testing library for Neovim plugins)
- Uses busted-style syntax (describe/it/before_each/after_each)
- Invoked via Neovim command: `:PlenaryBustedDirectory tests/`

**Assertion Library:**
- plenary's built-in assertions via `assert`
- Common assertions: `assert.are.equal()`, `assert.is_nil()`, `assert.is_truthy()`, `assert.is_function()`, `assert.is_table()`

**Run Commands:**
```bash
:PlenaryBustedDirectory tests/              # Run all tests
:PlenaryBusted tests/core/shots_spec.lua    # Run specific test file
```

No automated CI test runner detected in repository; tests are run manually in Neovim.

## Test File Organization

**Location:**
- Tests co-located with source in `tests/` directory mirroring `lua/shooter/` structure
- Test files in: `tests/core/`, `tests/tmux/`, `tests/telescope/`, `tests/tools/`, `tests/dashboard/`, `tests/providers/`

**Naming:**
- Pattern: `<module>_spec.lua` for each source module
- Example: `lua/shooter/core/shots.lua` → `tests/core/shots_spec.lua`
- 25 test files total covering all major modules

**Structure:**
```
tests/
├── core/
│   ├── shots_spec.lua
│   ├── project_spec.lua
│   ├── analytics_spec.lua
│   └── ...
├── tmux/
│   ├── shell_spec.lua
│   ├── init_spec.lua
│   └── ...
├── tools/
│   ├── token_counter_spec.lua
│   └── ...
```

## Test Structure

**Suite Organization:**
```lua
-- Test suite for shooter.core.shots module
local shots = require('shooter.core.shots')

describe('shots module', function()
  before_each(function()
    -- Set up test environment
  end)

  after_each(function()
    -- Clean up
  end)

  describe('find_current_shot', function()
    it('finds shot at cursor position', function()
      -- Arrange: Create test buffer
      -- Act: Call function
      -- Assert: Verify result
    end)
  end)
end)
```

**Patterns:**
- `describe()` blocks organize tests by function or feature
- `it()` blocks describe single test case
- `before_each()` for setup before each test
- `after_each()` for cleanup (usually empty)
- Test names read as behavior: "finds shot at cursor position", "returns nil when no shot found"

**Example from `shots_spec.lua`:**
```lua
describe('shots module', function()
  describe('find_current_shot', function()
    it('finds shot at cursor position', function()
      -- Create test buffer with shots
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test File',
        '',
        '## shot 1',
        'First shot content',
        '',
        '## shot 2',
        'Second shot content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      -- Test finding shot 1
      local start, finish, header = shots.find_current_shot(bufnr, 3)
      assert.are.equal(3, start)
      assert.are.equal(4, finish)
      assert.are.equal(3, header)
    end)
  end)
end)
```

## Mocking

**Framework:** No explicit mocking library detected (plenary doesn't include mock library)

**Patterns:**
- Lua tables used as test doubles: Create buffer directly with `vim.api.nvim_create_buf(false, true)`
- State passed as function parameters for testability: See `tmux/init.lua` - operations receive detect/send/messages modules
- Pcall guards in test code to handle optional dependencies:
  ```lua
  local ok, oil = pcall(require, 'oil')
  if ok then
    -- test oil functionality
  end
  ```

**What to Mock:**
- External system commands: Use `vim.fn.systemlist()` return values directly in setup
- File operations: Use temp buffers instead of disk (see `shots_spec.lua`)
- Vim API calls: Create buffers and test with actual API

**What NOT to Mock:**
- Internal module functions: Test through public API
- Vim API itself: Use real buffers and cursors in tests
- Table data structures: Use literal tables in tests

## Fixtures and Factories

**Test Data:**
- Literal test data inline in tests (no factory files)
- Buffers created per-test:
  ```lua
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '# Test File',
    '## shot 1',
    'content'
  })
  ```
- Reusable test data patterns:
  - Markdown with shots: title, empty lines, shot headers, content
  - Executed shot headers with timestamps: `'## x shot 1 (2026-01-20 12:00:00)'`
  - Open vs executed shot patterns

**Location:**
- No separate fixture files
- Test data defined inline in `it()` blocks
- Promotes test readability (data close to assertions)

## Coverage

**Requirements:** Not enforced (no coverage configuration found)

**View Coverage:**
- No documented coverage reporting
- Tests are manual and ad-hoc
- Focus is on behavior coverage, not line coverage

## Test Types

**Unit Tests:**
- Most tests: Functions like `find_current_shot()`, `parse_shot_header()`, `get_shot_content()` tested in isolation
- Create minimal test buffers with sample data
- Assert on return values and side effects
- Example: `shots_spec.lua` tests individual shot detection logic

**Integration Tests:**
- Tests verifying module structure: `assert.is_function(analytics.generate_report)` in `analytics_spec.lua`
- Tests checking exported functions exist
- Minimal integration (mostly checking public API surface)

**E2E Tests:**
- Not present in codebase
- Plugin is interactive (Vim commands, keybindings); would require separate system testing

## Common Patterns

**Async Testing:**
- No async patterns detected
- Vim scheduling handled via `utils.defer()` in code, not in tests
- Tests run synchronously with buffer state

**Error Testing:**
```lua
it('returns nil when no shot found', function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local lines = {'# No shots here', 'Just text'}
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  local start, finish, header = shots.find_current_shot(bufnr, 1)
  assert.is_nil(start)
  assert.is_nil(finish)
  assert.is_nil(header)
end)
```

**String/Regex Testing:**
- Used heavily for pattern matching: `assert.is_truthy(result:match('^## x shot 1'))`
- Negative matching: `assert.is_falsy(result:match('2026%-01%-20 12:00:00'))`

**Table Testing:**
- Iterate over test cases and apply assertions:
  ```lua
  local test_cases = {
    { cmd = 'zsh', expected = true },
    { cmd = 'bash', expected = true },
    { cmd = 'nvim', expected = false },
  }
  for _, tc in ipairs(test_cases) do
    assert.are.equal(tc.expected, is_shell_pane(tc.cmd))
  end
  ```

**Property Checking:**
- Validate structure in `project_spec.lua`:
  ```lua
  it('exports expected functions', function()
    assert.is_function(project.has_projects)
    assert.is_function(project.get_projects_dir)
    assert.is_function(project.list_projects)
  end)
  ```
- Ensures module API contract

## Module Structure Testing

Tests verify both behavior and exported API:

**Example from `analytics_spec.lua`:**
```lua
describe('module structure', function()
  it('exports expected functions', function()
    assert.is_function(analytics.generate_report)
    assert.is_function(analytics.show)
    assert.is_function(analytics.show_global)
    assert.is_function(analytics.show_project)
  end)
end)

describe('generate_report', function()
  it('returns a table of lines', function()
    local lines = analytics.generate_report(nil)
    assert.is_table(lines)
    assert.is_true(#lines > 0)
  end)

  it('includes header in report', function()
    local lines = analytics.generate_report(nil)
    assert.is_true(lines[1]:match('# Shooter Analytics') ~= nil)
  end)
end)
```

Combines structural validation with functional testing of report generation.

## Test Scope

Tests focus on:
- **Module-level behavior**: What does the function return?
- **Edge cases**: Empty inputs, nil values, boundary conditions
- **Regex patterns**: Shot header matching ignoring code blocks
- **Table structure**: Correct field names in returned tables
- **Timestamp handling**: Parsing and updating timestamps in headers

Tests avoid:
- System integration (no real tmux testing)
- File I/O to disk (use buffers)
- Command execution
- Neovim autocommands
- Complex workflow scenarios

---

*Testing analysis: 2026-01-30*
