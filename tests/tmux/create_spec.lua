-- Test suite for shooter.tmux.create module
local create = require('shooter.tmux.create')

describe('create module', function()
  describe('module structure', function()
    it('exports expected functions', function()
      assert.is_function(create.start_claude_in_pane)
      assert.is_function(create.create_new_pane)
      assert.is_function(create.create_left_pane)
      assert.is_function(create.create_claude_pane)
      assert.is_function(create.is_pane_running_claude)
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

  describe('PROVIDER_CMDS constant', function()
    it('uses correct claude command with flags via jobstart', function()
      -- start_claude_in_pane uses vim.fn.jobstart to send keys
      -- Verify it calls jobstart with the expected tmux send-keys args
      local captured_args = {}
      local original_jobstart = vim.fn.jobstart
      local original_jobwait = vim.fn.jobwait
      local original_wait = vim.wait
      vim.fn.jobstart = function(cmd, _)
        table.insert(captured_args, cmd)
        return 1
      end
      vim.fn.jobwait = function() return {0} end
      vim.wait = function() return true end

      create.start_claude_in_pane('%123')

      vim.fn.jobstart = original_jobstart
      vim.fn.jobwait = original_jobwait
      vim.wait = original_wait

      -- Second jobstart call sends the actual command
      assert.is_true(#captured_args >= 2, 'Should have at least 2 jobstart calls')
      local cmd_call = captured_args[2]
      -- The command args should include the claude command string
      local cmd_str = table.concat(cmd_call, ' ')
      assert.is_truthy(cmd_str:match('claude %-c %-%-dangerously%-skip%-permissions'),
        "Command should include -c --dangerously-skip-permissions flags")
    end)
  end)
end)
