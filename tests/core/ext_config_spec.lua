-- Tests for core/ext_config.lua
local ext_config = require('shooter.core.ext_config')

describe('core.ext_config', function()
  describe('parse_yaml', function()
    it('should parse simple key-value pairs', function()
      local result = ext_config.parse_yaml('name: hello\ncount: 42\nenabled: true')
      assert.equals('hello', result.name)
      assert.equals(42, result.count)
      assert.is_true(result.enabled)
    end)

    it('should parse nested keys', function()
      local yaml = 'file:\n  first_shot_color: "#e6d5b8"\n  first_shot_debounce_in_ms: 500'
      local result = ext_config.parse_yaml(yaml)
      assert.is_table(result.file)
      assert.equals('#e6d5b8', result.file.first_shot_color)
      assert.equals(500, result.file.first_shot_debounce_in_ms)
    end)

    it('should handle booleans', function()
      local result = ext_config.parse_yaml('a: true\nb: false')
      assert.is_true(result.a)
      assert.is_false(result.b)
    end)

    it('should skip comments and blank lines', function()
      local yaml = '# comment\nkey: value\n\n# another\nother: data'
      local result = ext_config.parse_yaml(yaml)
      assert.equals('value', result.key)
      assert.equals('data', result.other)
    end)

    it('should strip quoted strings', function()
      local result = ext_config.parse_yaml('color: "#ff0000"')
      assert.equals('#ff0000', result.color)
    end)

    it('should handle deeply nested structures', function()
      local yaml = 'a:\n  b:\n    c: deep'
      local result = ext_config.parse_yaml(yaml)
      assert.equals('deep', result.a.b.c)
    end)
  end)

  describe('serialize_yaml', function()
    it('should serialize flat table', function()
      local yaml = ext_config.serialize_yaml({ name = 'test', count = 42 })
      assert.matches('name: test', yaml)
      assert.matches('count: 42', yaml)
    end)

    it('should serialize nested table', function()
      local yaml = ext_config.serialize_yaml({ file = { color = '#abc' } })
      assert.matches('file:', yaml)
      assert.matches('  color:', yaml)
    end)

    it('should quote strings starting with #', function()
      local yaml = ext_config.serialize_yaml({ color = '#ff0000' })
      assert.matches('"#ff0000"', yaml)
    end)
  end)

  describe('path accessors', function()
    it('base_dir should point to ~/.config/shooter/nvim', function()
      local dir = ext_config.base_dir()
      assert.matches('shooter/nvim$', dir)
    end)

    it('sessions_dir should be under base_dir', function()
      local dir = ext_config.sessions_dir()
      assert.matches('shooter/nvim/sessions$', dir)
    end)

    it('tmp_dir should be under base_dir', function()
      local dir = ext_config.tmp_dir()
      assert.matches('shooter/nvim/tmp$', dir)
    end)

    it('filter_state_path should be under base_dir', function()
      local path = ext_config.filter_state_path()
      assert.matches('shooter/nvim/filter%-state%.json$', path)
    end)

    it('last_shotfile_path should include slug', function()
      local path = ext_config.last_shotfile_path('owner_repo')
      assert.matches('last%-shotfile%-owner_repo$', path)
    end)

    it('global_config_path should point to config.yaml', function()
      local path = ext_config.global_config_path()
      assert.matches('shooter/nvim/config%.yaml$', path)
    end)
  end)

  describe('get', function()
    -- Reset cache before each test
    before_each(function()
      ext_config.reload()
    end)

    it('should return default values', function()
      local color = ext_config.get('file.first_shot_color')
      assert.equals('#e6d5b8', color)
    end)

    it('should return default debounce', function()
      local debounce = ext_config.get('file.first_shot_debounce_in_ms')
      assert.equals(500, debounce)
    end)

    it('should return nil for missing paths', function()
      local val = ext_config.get('nonexistent.path.here')
      assert.is_nil(val)
    end)
  end)

  describe('reload', function()
    it('should invalidate cache', function()
      -- Load once to populate cache
      ext_config.load()
      -- Reload invalidates
      ext_config.reload()
      -- Next load should re-read from disk
      local cfg = ext_config.load()
      assert.is_table(cfg)
      assert.is_table(cfg.file)
    end)
  end)

  describe('DEFAULTS', function()
    it('should have file.first_shot_color', function()
      assert.equals('#e6d5b8', ext_config.DEFAULTS.file.first_shot_color)
    end)

    it('should have file.first_shot_debounce_in_ms', function()
      assert.equals(500, ext_config.DEFAULTS.file.first_shot_debounce_in_ms)
    end)
  end)
end)
