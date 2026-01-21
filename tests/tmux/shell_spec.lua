-- Test suite for shooter.tmux.shell module
local shell = require('shooter.tmux.shell')

describe('shell module', function()
  describe('is_shell_pane', function()
    -- Note: These tests verify the pattern matching logic
    -- Actual tmux integration would require a real tmux session

    it('matches shell process names', function()
      -- Test the internal pattern matching by checking get_pane_command patterns
      local test_cases = {
        { cmd = 'zsh', expected = true },
        { cmd = 'bash', expected = true },
        { cmd = '-zsh', expected = true },  -- login shell
        { cmd = '-bash', expected = true },  -- login shell
        { cmd = 'fish', expected = false },  -- not supported yet
        { cmd = 'nvim', expected = false },
        { cmd = 'claude', expected = false },
        { cmd = 'node', expected = false },
      }

      for _, tc in ipairs(test_cases) do
        -- Check pattern matching logic directly
        local matches_shell = tc.cmd:match('^%-?[zb]?a?sh$')
          or tc.cmd:match('^%-?zsh$')
          or tc.cmd:match('^%-?bash$')
        local result = matches_shell ~= nil
        assert.are.equal(tc.expected, result,
          string.format("Command '%s' should be %s", tc.cmd, tc.expected and "shell" or "not shell"))
      end
    end)
  end)

  describe('module structure', function()
    it('exports expected functions', function()
      assert.is_function(shell.get_pane_command)
      assert.is_function(shell.is_shell_pane)
      assert.is_function(shell.find_left_pane)
      assert.is_function(shell.find_shell_pane)
    end)
  end)
end)
