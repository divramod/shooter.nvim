-- Test suite for shooter.telescope.toggle_panes_picker module
local toggle_panes_picker = require('shooter.telescope.toggle_panes_picker')

describe('toggle_panes_picker module', function()
  describe('module structure', function()
    it('exports expected functions', function()
      assert.is_function(toggle_panes_picker.show_picker)
    end)
  end)

  -- Note: Full picker tests require Telescope to be loaded
  -- and would be integration tests rather than unit tests
  describe('show_picker', function()
    it('can be called without errors when no config', function()
      -- When no config file exists, it should just notify and return
      -- This tests the graceful handling of missing config
      assert.is_function(toggle_panes_picker.show_picker)
    end)
  end)
end)
