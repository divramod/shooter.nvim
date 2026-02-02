-- Tests for script_panes module
local script_panes = require('shooter.tmux.script_panes')

describe('script_panes module', function()
  describe('module structure', function()
    it('exports expected functions', function()
      assert.is_function(script_panes.get_script_panes)
    end)
  end)

  describe('get_script_panes', function()
    it('returns a table', function()
      local panes = script_panes.get_script_panes()
      assert.is_table(panes)
    end)

    it('panes have required fields', function()
      local panes = script_panes.get_script_panes()
      for _, pane in ipairs(panes) do
        assert.is_string(pane.name)
        assert.is_table(pane.commands)
        assert.is_number(pane.height)
        assert.is_true(pane.name:match('^script:'))
        assert.is_true(pane.auto_generated)
      end
    end)
  end)
end)
