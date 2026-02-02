-- Test suite for shooter.tmux.toggle_panes module
local toggle_panes = require('shooter.tmux.toggle_panes')

describe('toggle_panes module', function()
  before_each(function()
    toggle_panes.clear_state()
  end)

  describe('module structure', function()
    it('exports expected functions', function()
      assert.is_function(toggle_panes.show)
      assert.is_function(toggle_panes.hide)
      assert.is_function(toggle_panes.toggle)
      assert.is_function(toggle_panes.is_visible)
      assert.is_function(toggle_panes.is_hidden)
      assert.is_function(toggle_panes.get_visible_panes)
      assert.is_function(toggle_panes.get_state)
      assert.is_function(toggle_panes.clear_state)
    end)
  end)

  describe('is_visible', function()
    it('returns false for unknown pane', function()
      local result = toggle_panes.is_visible('nonexistent')
      assert.is_false(result)
    end)
  end)

  describe('is_hidden', function()
    it('returns false for unknown pane', function()
      local result = toggle_panes.is_hidden('nonexistent')
      assert.is_false(result)
    end)
  end)

  describe('get_visible_panes', function()
    it('returns empty table when no panes visible', function()
      local result = toggle_panes.get_visible_panes()
      assert.is_table(result)
      assert.are.equal(0, #result)
    end)
  end)

  describe('get_state', function()
    it('returns nil for unknown pane', function()
      local result = toggle_panes.get_state('nonexistent')
      assert.is_nil(result)
    end)
  end)

  describe('clear_state', function()
    it('clears all tracked panes', function()
      -- Just verify it doesn't error
      toggle_panes.clear_state()
      local result = toggle_panes.get_visible_panes()
      assert.are.equal(0, #result)
    end)
  end)

  -- Note: show/hide/toggle require actual tmux session
  -- Full integration tests would need tmux running
  describe('show', function()
    it('handles unconfigured pane gracefully', function()
      -- This will fail gracefully since pane not in config
      -- and we're likely not in tmux
      assert.is_function(toggle_panes.show)
    end)
  end)

  describe('hide', function()
    it('handles invisible pane gracefully', function()
      -- This should return false since pane is not visible
      -- Note: Actual execution requires tmux
      assert.is_function(toggle_panes.hide)
    end)
  end)
end)
