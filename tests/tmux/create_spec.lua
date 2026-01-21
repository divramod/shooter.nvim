-- Test suite for shooter.tmux.create module
local create = require('shooter.tmux.create')

describe('create module', function()
  describe('module structure', function()
    it('exports expected functions', function()
      assert.is_function(create.start_claude_in_pane)
      assert.is_function(create.create_left_pane)
      assert.is_function(create.create_claude_pane)
      assert.is_function(create.wait_for_claude)
      assert.is_function(create.start_and_wait_for_claude)
      assert.is_function(create.find_or_create_claude_pane)
    end)
  end)

  describe('start_claude_in_pane', function()
    it('returns false when pane_id is nil', function()
      local success, err = create.start_claude_in_pane(nil)
      assert.is_false(success)
      assert.are.equal("No pane ID provided", err)
    end)
  end)

  describe('CLAUDE_CMD constant', function()
    it('uses correct claude command with flags', function()
      -- The CLAUDE_CMD should include -c and --dangerously-skip-permissions
      -- We verify this by checking the function behavior indirectly
      -- since the constant is local

      -- Create a mock to capture the command
      local captured_cmd = nil
      local original_execute = os.execute
      os.execute = function(cmd)
        captured_cmd = cmd
        return 0
      end

      create.start_claude_in_pane('%123')

      os.execute = original_execute

      assert.is_truthy(captured_cmd)
      assert.is_truthy(captured_cmd:match('claude %-c %-%-dangerously%-skip%-permissions'),
        "Command should include -c --dangerously-skip-permissions flags")
    end)
  end)
end)
