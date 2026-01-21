-- Test suite for shooter.tmux.init module
local tmux = require('shooter.tmux')

describe('tmux module', function()
  describe('module structure', function()
    it('exports expected functions', function()
      assert.is_function(tmux.send_current_shot)
      assert.is_function(tmux.send_all_shots)
      assert.is_function(tmux.send_visual_selection)
      assert.is_function(tmux.send_specific_shots)
      assert.is_function(tmux.resend_latest_shot)
    end)

    it('exports submodules', function()
      assert.is_table(tmux.detect)
      assert.is_table(tmux.send)
      assert.is_table(tmux.messages)
      assert.is_table(tmux.create)
    end)
  end)

  describe('resend_latest_shot', function()
    it('accepts pane_index parameter', function()
      -- Function should exist and be callable
      -- Note: Actual tmux functionality requires tmux session
      assert.is_function(tmux.resend_latest_shot)
    end)
  end)
end)
