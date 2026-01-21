-- Tests for tmux pane visibility toggle
local panes = require('shooter.tmux.panes')

describe('panes module', function()
  describe('is_hidden', function()
    it('returns false for non-hidden panes', function()
      -- Fresh state, nothing is hidden
      assert.is_false(panes.is_hidden(1))
      assert.is_false(panes.is_hidden(2))
      assert.is_false(panes.is_hidden(9))
    end)
  end)

  describe('get_status', function()
    it('returns empty table when no panes hidden', function()
      local status = panes.get_status()
      assert.is_table(status)
      -- Count should be 0 for fresh state
      local count = 0
      for _ in pairs(status) do count = count + 1 end
      assert.equals(0, count)
    end)
  end)

  describe('toggle', function()
    it('handles not in tmux gracefully', function()
      -- This test will pass outside tmux (the common test environment)
      -- It should not error, just notify
      assert.has_no.errors(function()
        panes.toggle(1)
      end)
    end)

    it('handles invalid pane index gracefully', function()
      -- Should not error even for out-of-range index
      assert.has_no.errors(function()
        panes.toggle(99)
      end)
    end)
  end)
end)
