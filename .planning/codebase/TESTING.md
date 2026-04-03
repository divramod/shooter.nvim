# Testing Patterns

**Analysis Date:** 2026-04-03

## Test Framework

**Runner:**
- plenary.nvim test harness (busted-style)
- Config: `tests/minimal_init.lua`
- CI: `.github/workflows/test.yml`

**Assertion Library:**
- Luassert (bundled with plenary.nvim) -- `assert.are.equal`, `assert.is_truthy`, `assert.is_nil`, etc.

**Run Commands:**
```bash
# Run all tests (headless Neovim)
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "lua require('plenary.test_harness').test_directory('tests/', {minimal_init = 'tests/minimal_init.lua', sequential = true})"

# Run a single test file
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/core/shots_spec.lua"

# Run tests in a directory
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/core/"
```

## Test File Organization

**Location:**
- Separate `tests/` directory at project root, mirroring `lua/shooter/` structure

**Naming:**
- `<module_name>_spec.lua` -- e.g., `shots_spec.lua` for `lua/shooter/core/shots.lua`

**Structure:**
```
tests/
├── minimal_init.lua           # Test environment bootstrap
├── filter_state_spec.lua      # Root-level module tests
├── analytics/
│   └── data_spec.lua
├── core/
│   ├── analytics_spec.lua
│   ├── ext_config_spec.lua
│   ├── greenkeep_spec.lua
│   ├── project_spec.lua
│   ├── rename_spec.lua
│   ├── renumber_spec.lua
│   ├── shot_actions_spec.lua
│   ├── shot_delete_spec.lua
│   ├── shots_spec.lua
│   ├── sound_spec.lua
│   └── templates_spec.lua
├── dashboard/
│   └── data_spec.lua
├── providers/
│   ├── codex_spec.lua
│   ├── gemini_spec.lua
│   └── init_spec.lua
├── session/
│   ├── defaults_spec.lua
│   ├── filter_spec.lua
│   ├── sort_spec.lua
│   └── storage_spec.lua
├── telescope/
│   ├── helpers_spec.lua
│   └── toggle_panes_picker_spec.lua
├── tmux/
│   ├── config_panes_spec.lua
│   ├── create_spec.lua
│   ├── hidden_session_spec.lua
│   ├── init_spec.lua
│   ├── panes_spec.lua
│   ├── renumber_helper_spec.lua
│   ├── script_panes_spec.lua
│   ├── shell_spec.lua
│   └── toggle_panes_spec.lua
└── tools/
    ├── clipboard_image_spec.lua
    ├── obsidian_spec.lua
    ├── response_viewer_spec.lua
    └── token_counter_spec.lua
```

## Test Environment Setup

**Minimal init** (`tests/minimal_init.lua`):
```lua
-- Sets up clean Neovim runtime
vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.cmd([[set packpath=/tmp/nvim/site]])

-- Auto-installs plenary.nvim to /tmp/nvim/site/pack/packer/start/
-- Adds shooter.nvim (cwd) to runtimepath
-- Disables swapfile, enables hidden buffers
```

## Test Structure

**Suite Organization:**
```lua
-- Standard test file pattern
local module = require('shooter.some.module')

describe('module name', function()
  before_each(function()
    -- Setup: create buffers, temp files, save config state
  end)

  after_each(function()
    -- Cleanup: remove temp files, restore config
  end)

  describe('function_name', function()
    it('describes expected behavior', function()
      -- Arrange
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = { '## shot 1', 'content' }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      -- Act
      local result = module.function_name(bufnr, 1)

      -- Assert
      assert.are.equal(expected, result)
    end)
  end)
end)
```

**Patterns:**
- Nested `describe` blocks: outer for module, inner for each function
- `before_each`/`after_each` for setup/teardown (not `before`/`after`)
- `it` blocks use descriptive present-tense strings: `'finds shot at cursor position'`
- No shared mutable state between `it` blocks

## Neovim Buffer Testing

**Creating test buffers:**
```lua
local bufnr = vim.api.nvim_create_buf(false, true)  -- unlisted, scratch
local lines = { '## shot 1', 'content', '', '## shot 2', 'more' }
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
```

**Reading buffer results:**
```lua
local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
assert.are.equal('## x shot 1', result[1])
```

This is the primary testing pattern -- most tests create scratch buffers, populate them with known content, call a function, then assert on buffer state.

## Mocking

**Framework:** Manual mocking (no dedicated mock library)

**Patterns:**
```lua
-- Save-and-restore pattern for mocking
local original_echo = require('shooter.utils').echo
local echo_called = false
require('shooter.utils').echo = function(msg)
  echo_called = true
  assert.is_truthy(msg:match('disabled'))
end

-- ... run code under test ...

require('shooter.utils').echo = original_echo  -- restore
assert.is_true(echo_called)
```

**What to Mock:**
- `utils.echo` when testing notification behavior (see `tests/core/sound_spec.lua`)
- Config values via `config.set()` before test, restore in `after_each`

**What NOT to Mock:**
- Neovim buffer API (`vim.api.nvim_create_buf`, `nvim_buf_set_lines`) -- use real scratch buffers
- File I/O -- use real temp files in `/tmp/`
- Module requires -- use real module loading

## Fixtures and Factories

**Test Data:**
```lua
-- Inline string content for file tests
local original_content = [[# Old Title

## shot 1
some content here

## shot 2
more content
]]
utils.write_file(filepath, original_content)
```

**Temp file pattern:**
```lua
local test_dir = '/tmp/shooter_rename_test'

before_each(function()
  os.execute('mkdir -p ' .. test_dir)
end)

after_each(function()
  os.execute('rm -rf ' .. test_dir)
end)
```

**Location:**
- No separate fixtures directory. Test data is inline in spec files.
- Temp files created in `/tmp/` with descriptive names

## Coverage

**Requirements:** 80%+ test coverage for new code (per `CLAUDE.md` "Always Do" rules)

**View Coverage:**
- No coverage tooling configured. Coverage is a policy requirement, not enforced by tooling.

## Test Types

**Unit Tests:**
- All tests are unit tests targeting individual module functions
- Tests run in headless Neovim with plenary test harness
- Buffer manipulation tests use real Neovim API with scratch buffers
- File operation tests use real filesystem with `/tmp/` directories

**Integration Tests:**
- No separate integration test suite
- Some tests verify module interface contracts (e.g., `tests/providers/init_spec.lua` checks all providers implement required methods)
- Tmux-dependent functionality tests gracefully degrade outside tmux:
  ```lua
  it('handles not in tmux gracefully', function()
    assert.has_no.errors(function()
      panes.toggle(1)
    end)
  end)
  ```

**E2E Tests:**
- Not used

## CI Configuration

**GitHub Actions** (`.github/workflows/test.yml`):
- Runs on push/PR to main/master
- Tests against Neovim stable and nightly
- Installs plenary.nvim as test dependency
- 120-second timeout per test run
- Parses output for `Failed :.*[1-9]` pattern to detect failures
- luacheck lint step (optional, `continue-on-error: true`)

## Common Assertion Patterns

**Equality:**
```lua
assert.are.equal(expected, actual)
assert.equals(expected, actual)  -- shorthand, also used
```

**Truthiness/nil:**
```lua
assert.is_truthy(value)
assert.is_falsy(value)
assert.is_nil(value)
assert.is_not_nil(value)
assert.is_true(value)
assert.is_false(value)
```

**Type checking:**
```lua
assert.is_function(module.some_fn)
assert.is_table(result)
assert.is_string(name)
```

**Pattern matching:**
```lua
assert.is_truthy(result:match('^## x shot 1'))
assert.matches('shooter/nvim$', dir)
assert.truthy(new_content:find('## shot 1'))
```

**Error-free execution:**
```lua
assert.has_no.errors(function()
  panes.toggle(1)
end)
```

**Custom message on failure:**
```lua
assert.is_true(has_claude, 'Should have claude pattern')
assert.are.equal(tc.expected, result,
  string.format("Command '%s' should be %s", tc.cmd, tc.expected and "shell" or "not shell"))
```

## Config State Management in Tests

**Pattern for testing config-dependent code:**
```lua
local original_config

before_each(function()
  original_config = {
    enabled = config.get('sound.enabled'),
    file = config.get('sound.file'),
    volume = config.get('sound.volume'),
  }
end)

after_each(function()
  config.set('sound.enabled', original_config.enabled)
  config.set('sound.file', original_config.file)
  config.set('sound.volume', original_config.volume)
end)
```

Use `config.set()` to inject test values, restore originals in `after_each`.

## Adding New Tests

**For a new module at `lua/shooter/core/foo.lua`:**
1. Create `tests/core/foo_spec.lua`
2. Require the module: `local foo = require('shooter.core.foo')`
3. Use nested `describe`/`it` blocks following existing patterns
4. Use scratch buffers for buffer-dependent tests
5. Use `/tmp/` for file I/O tests with cleanup in `after_each`
6. Tests run automatically in CI via `test_directory('tests/')` glob

**Rules from CLAUDE.md:**
- Never delete existing tests
- Never skip tests (`.skip()`, `test.skip()`, etc.)
- Clean up test resources (no orphan processes or temp files)
- 80%+ test coverage for new code

---

*Testing analysis: 2026-04-03*
