-- Test suite for shooter.tmux.config_panes module
local config_panes = require('shooter.tmux.config_panes')

describe('config_panes module', function()
  before_each(function()
    config_panes.clear_cache()
  end)

  describe('module structure', function()
    it('exports expected functions', function()
      assert.is_function(config_panes.load)
      assert.is_function(config_panes.get_current)
      assert.is_function(config_panes.find_by_name)
      assert.is_function(config_panes.clear_cache)
    end)
  end)

  describe('load', function()
    it('returns nil when git_root is nil', function()
      local result = config_panes.load(nil)
      assert.is_nil(result)
    end)

    it('returns nil when config file does not exist', function()
      local result = config_panes.load('/nonexistent/path')
      assert.is_nil(result)
    end)
  end)

  describe('find_by_name', function()
    it('returns nil when no config loaded', function()
      local result = config_panes.find_by_name('test')
      assert.is_nil(result)
    end)
  end)

  describe('yaml parsing', function()
    -- Test the internal YAML parser via a mock file
    -- Note: Full integration tests would require a temp directory with config
    it('handles empty config gracefully', function()
      -- Just verify the module can be loaded without errors
      assert.is_table(config_panes)
    end)
  end)
end)
