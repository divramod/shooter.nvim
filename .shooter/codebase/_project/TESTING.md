# Testing Patterns

**Analysis Date:** 2026-02-08

## Test Framework

**Runner:**
- Busted (Lua test framework)
- Configuration file: Not present (uses busted defaults)
- Invoked via: Test infrastructure presumed via CI or local test runner

**Assertion Library:**
- Busted's built-in assertions: `assert.is_true()`, `assert.is_nil()`, `assert.are.equal()`
- Custom matchers: `assert.matches()` for regex, `assert.is_function()` for type checking

**Run Commands:**
```bash
busted                     # Run all tests (assumed)
busted --helpers           # Show available assertion helpers
```

Note: No explicit test runner script found in repo. Tests located in `tests/` directory following Busted conventions.

## Test File Organization

**Location:**
- Tests co-located with source in parallel structure:
  - Source: `lua/shooter/core/shots.lua` → Test: `tests/core/shots_spec.lua`
  - Source: `lua/shooter/tools/token_counter.lua` → Test: `tests/tools/token_counter_spec.lua`
  - Source: `lua/shooter/tmux/init.lua` → Test: `tests/tmux/init_spec.lua`

**Naming:**
- Test files: `module_name_spec.lua` (suffix `_spec.lua`)
- Test directories: Match source structure under `tests/` root
- 34 test files covering 30+ modules

**Structure:**
```
tests/
├── core/              # Tests for lua/shooter/core/
│   ├── shots_spec.lua
│   ├── project_spec.lua
│   ├── rename_spec.lua
│   └── ... (15 more)
├── tools/             # Tests for lua/shooter/tools/
│   ├── token_counter_spec.lua
│   ├── obsidian_spec.lua
│   └── ...
├── tmux/              # Tests for lua/shooter/tmux/
│   ├── init_spec.lua
│   ├── panes_spec.lua
│   └── ...
├── telescope/         # Tests for lua/shooter/telescope/
├── providers/         # Tests for lua/shooter/providers/
├── dashboard/         # Tests for lua/shooter/dashboard/
├── session/           # Tests for lua/shooter/session/
├── analytics/         # Tests for lua/shooter/analytics/
└── filter_state_spec.lua
```

## Test Structure

**Suite Organization:**
```lua
describe('module name', function()
  before_each(function()
    -- Setup before each test
  end)

  after_each(function()
    -- Cleanup after each test
  end)

  describe('function name or feature', function()
    it('does something specific', function()
      -- Test implementation
    end)

    it('handles error condition', function()
      -- Test implementation
    end)
  end)
end)
```

**Patterns:**

1. **Module structure tests** - Verify exports:
```lua
describe('module structure', function()
  it('exports expected functions', function()
    assert.is_function(project.has_projects)
    assert.is_function(project.get_projects_dir)
    assert.is_function(project.list_projects)
  end)
end)
```

2. **Setup/Teardown** - Create test fixtures:
```lua
local test_dir = '/tmp/shooter_rename_test'

before_each(function()
  os.execute('mkdir -p ' .. test_dir)
end)

after_each(function()
  os.execute('rm -rf ' .. test_dir)
end)
```

3. **Buffer manipulation tests** - Use vim API directly:
```lua
it('finds shot at cursor position', function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local lines = {
    '# Test File',
    '',
    '## shot 1',
    'First shot content',
  }
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  local start, finish, header = shots.find_current_shot(bufnr, 3)
  assert.are.equal(3, start)
  assert.are.equal(4, finish)
end)
```

4. **Conditional/pending tests** - Skip when prerequisites missing:
```lua
describe('with ttok installed', function()
  local ttok_available = vim.fn.executable('ttok') == 1

  it('counts tokens in file', function()
    if not ttok_available then
      pending('ttok not installed')
      return
    end
    -- Test implementation
  end)
end)
```

## Mocking

**Framework:** Manual mocking via direct assignment

**Patterns:**

1. **Mock vim.notify to avoid output:**
```lua
local original_notify = vim.notify
before_each(function()
  vim.notify = function() end
end)

after_each(function()
  vim.notify = original_notify
end)
```

2. **Mock utility functions:**
```lua
local original_echo = require('shooter.utils').echo
before_each(function()
  require('shooter.utils').echo = function() end
end)

after_each(function()
  require('shooter.utils').echo = original_echo
end)
```

3. **No dependency injection** - Tests modify modules directly during setup
4. **No test doubles** - Real module functions called; only vim-level side effects mocked
5. **Spy pattern not used** - Cannot verify calls, only observable results

**What to Mock:**
- Vim API calls with side effects: `vim.notify()`, `vim.cmd()`
- User-facing output: `utils.echo()`, `utils.notify()`
- Optional external dependencies: Check availability with `vim.fn.executable()`

**What NOT to Mock:**
- Core logic functions (test the real behavior)
- Buffer operations (use actual vim buffers in tests)
- File system for focused tests (but use temp dirs with cleanup)
- Module requires (load real modules)

## Fixtures and Factories

**Test Data:**

1. **In-memory buffers** - Most common fixture:
```lua
local bufnr = vim.api.nvim_create_buf(false, true)
local lines = {
  '# Test File',
  '',
  '## shot 1',
  'First shot content',
}
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
```

2. **File system fixtures** - For rename/move tests:
```lua
local test_dir = '/tmp/shooter_test'
before_each(function()
  os.execute('mkdir -p ' .. test_dir)
end)

after_each(function()
  os.execute('rm -rf ' .. test_dir)
end)

local filepath = test_dir .. '/test-file.md'
utils.write_file(filepath, 'content here')
```

3. **Inline test data** - Simple string/table definitions:
```lua
local lines = {
  '# Test',
  '## shot 1',
  'content',
  '## x shot 2',
  'done',
}
```

**Location:**
- Fixtures defined within test blocks (no shared factory files)
- Temporary files use `/tmp/shooter_*` naming with cleanup in `after_each()`
- Buffer creation is idiomatic: `vim.api.nvim_create_buf(false, true)` for temporary buffers

## Coverage

**Requirements:** Not explicitly enforced (no `.luacov` config detected)

**Approach:**
- Pragmatic coverage: Core logic well-tested, some utilities minimal
- 34 test files with 3,684 lines of test code vs. 14,776 lines of source
- Ratio: ~1 line of test per 4 lines of source

**Coverage patterns:**
- **Core modules**: Multiple test cases (happy path, error cases, edge cases)
- **Utilities**: Basic tests, not exhaustive
- **Optional features**: Conditional tests when prerequisites missing

## Test Types

**Unit Tests:**
- Scope: Single function or cohesive module
- Approach: Test inputs and outputs in isolation
- Most tests in suite are unit tests
- Example: `shots.find_current_shot()` tested with various buffer states

**Integration Tests:**
- Scope: Multiple modules working together
- Not explicitly labeled but present in some tests
- Example: `shot_actions.create_new_shot()` tests buffer state after operation
- File system tests combining utils with core modules

**E2E Tests:**
- Not present in this codebase
- Plugin is interactive (Neovim UI); would require integration test setup

## Common Patterns

**Async Testing:**

Neovim operations are synchronous in tests (no explicit async patterns detected):
```lua
it('modifies buffer', function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {'# Title'})
  vim.api.nvim_set_current_buf(bufnr)

  -- Call function that modifies buffer
  shots.mark_shot_executed(bufnr, 1)

  -- Immediately check results (vim is sync in testing)
  local result = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
  assert.is_truthy(result:match('^## x shot 1'))
end)
```

**Error Testing:**

1. **Return value checking:**
```lua
it('returns nil for invalid input', function()
  local count, err = token_counter.count_tokens('')
  assert.is_nil(count)
  assert.is_not_nil(err)
  assert.matches('No file', err)
end)
```

2. **Exception-free (no pcall in tests)** - Tests expect functions to handle errors gracefully:
```lua
it('returns error for non-existent file', function()
  local count, err = token_counter.count_tokens('/nonexistent/file.txt')
  assert.is_nil(count)
  assert.is_not_nil(err)
  assert.matches('not readable', err)
end)
```

3. **State assertions after error:**
```lua
it('handles timestamp on already executed shot', function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local lines = {'## x shot 1 (2026-01-20 12:00:00)', 'content'}
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  shots.mark_shot_executed(bufnr, 1)

  local result = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
  assert.is_truthy(result:match('^## x shot 1'))
  assert.is_falsy(result:match('2026%-01%-20 12:00:00'))  -- Old timestamp gone
end)
```

**String Matching in Assertions:**

Busted's `assert.matches()` for regex:
```lua
assert.matches('not readable', err)                    -- Substring match
assert.matches('%d%d%d%d%-%d%d%-%d%d', timestamp)     -- Date format
assert.is_truthy(result:match('^## x shot 1'))        -- Lua string.match()
```

## Test Examples

**Complete test for shot finding:**
```lua
describe('find_current_shot', function()
  it('finds shot at cursor position', function()
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

    local start, finish, header = shots.find_current_shot(bufnr, 3)
    assert.are.equal(3, start)
    assert.are.equal(4, finish)
    assert.are.equal(3, header)
  end)

  it('returns nil when no shot found', function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local lines = {'# No shots here', 'Just text'}
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local start, finish, header = shots.find_current_shot(bufnr, 1)
    assert.is_nil(start)
    assert.is_nil(finish)
    assert.is_nil(header)
  end)

  it('ignores shot headers inside code blocks', function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local lines = {
      '# Test',
      '## shot 1',
      'Some content with code:',
      '```markdown',
      '## shot 99',
      'This is inside code',
      '```',
      '',
      '## shot 2',
      'Real shot 2 content',
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local open_shots = shots.find_open_shots(bufnr)
    assert.are.equal(2, #open_shots)
    assert.are.equal(2, open_shots[1].header_line)   -- shot 1
    assert.are.equal(9, open_shots[2].header_line)   -- shot 2
  end)
end)
```

---

*Testing analysis: 2026-02-08*
