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
      local yaml = 'file:\n  first_shot_of_the_day_prefix:\n    color_bg: ""\n    color_fg: "#888888"'
      local result = ext_config.parse_yaml(yaml)
      assert.is_table(result.file)
      assert.is_table(result.file.first_shot_of_the_day_prefix)
      assert.equals('', result.file.first_shot_of_the_day_prefix.color_bg)
      assert.equals('#888888', result.file.first_shot_of_the_day_prefix.color_fg)
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

    it('should not treat # inside quotes as comment', function()
      local result = ext_config.parse_yaml('bg: "#e6d5b8"')
      assert.equals('#e6d5b8', result.bg)
    end)

    it('should strip inline comments after values', function()
      local result = ext_config.parse_yaml('key: value # this is a comment')
      assert.equals('value', result.key)
    end)

    it('should handle deeply nested structures', function()
      local yaml = 'a:\n  b:\n    c: deep'
      local result = ext_config.parse_yaml(yaml)
      assert.equals('deep', result.a.b.c)
    end)

    it('should parse the full new config schema', function()
      local yaml = 'file:\n'
        .. '  first_shot_of_the_day_prefix:\n'
        .. '    color_bg: ""\n'
        .. '    color_fg: "#FF0011"\n'
        .. '  open_shots:\n'
        .. '    color_bg: "#00FF00"\n'
        .. '    color_fg: "#001100"\n'
        .. '  closed_shots_prefix:\n'
        .. '    color_bg: ""\n'
        .. '    color_fg: "#000011"'
      local result = ext_config.parse_yaml(yaml)
      assert.equals('', result.file.first_shot_of_the_day_prefix.color_bg)
      assert.equals('#FF0011', result.file.first_shot_of_the_day_prefix.color_fg)
      assert.equals('#00FF00', result.file.open_shots.color_bg)
      assert.equals('#001100', result.file.open_shots.color_fg)
      assert.equals('', result.file.closed_shots_prefix.color_bg)
      assert.equals('#000011', result.file.closed_shots_prefix.color_fg)
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
    it('base_dir should point to ~/.config/hal/util/shooter/nvim', function()
      local dir = ext_config.base_dir()
      assert.matches('hal/util/shooter/nvim$', dir)
    end)

    it('sessions_dir should be under base_dir', function()
      local dir = ext_config.sessions_dir()
      assert.matches('hal/util/shooter/nvim/sessions$', dir)
    end)

    it('bullets_dir should be under base_dir', function()
      local dir = ext_config.bullets_dir()
      assert.matches('hal/util/shooter/nvim/bullets$', dir)
    end)

    it('filter_state_path should be under base_dir', function()
      local path = ext_config.filter_state_path()
      assert.matches('hal/util/shooter/nvim/filter%-state%.json$', path)
    end)

    it('last_shotfile_path should include slug', function()
      local path = ext_config.last_shotfile_path('owner_repo')
      assert.matches('last%-shotfile%-owner_repo$', path)
    end)

    it('global_config_path should point to config.yaml', function()
      local path = ext_config.global_config_path()
      assert.matches('hal/util/shooter/nvim/config%.yaml$', path)
    end)
  end)

  describe('get', function()
    -- Reset cache before each test
    before_each(function()
      ext_config.reload()
    end)

    it('should return default day marker prefix bg color (empty = no bg)', function()
      local color = ext_config.get('file.first_shot_of_the_day_prefix.color_bg')
      assert.equals('', color)
    end)

    it('should return default day marker prefix fg color', function()
      local color = ext_config.get('file.first_shot_of_the_day_prefix.color_fg')
      assert.equals('#888888', color)
    end)

    it('should return default open shots bg color', function()
      local color = ext_config.get('file.open_shots.color_bg')
      assert.equals('#ffb347', color)
    end)

    it('should return default closed shots prefix bg color (empty = no bg)', function()
      local color = ext_config.get('file.closed_shots_prefix.color_bg')
      assert.equals('', color)
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
    it('should have file.first_shot_of_the_day_prefix.color_bg', function()
      assert.equals('', ext_config.DEFAULTS.file.first_shot_of_the_day_prefix.color_bg)
    end)

    it('should have file.first_shot_of_the_day_prefix.color_fg', function()
      assert.equals('#888888', ext_config.DEFAULTS.file.first_shot_of_the_day_prefix.color_fg)
    end)

    it('should have file.open_shots', function()
      assert.is_table(ext_config.DEFAULTS.file.open_shots)
      assert.equals('#ffb347', ext_config.DEFAULTS.file.open_shots.color_bg)
      assert.equals('#000000', ext_config.DEFAULTS.file.open_shots.color_fg)
    end)

    it('should have file.closed_shots_prefix', function()
      assert.is_table(ext_config.DEFAULTS.file.closed_shots_prefix)
      assert.equals('', ext_config.DEFAULTS.file.closed_shots_prefix.color_bg)
      assert.equals('#888888', ext_config.DEFAULTS.file.closed_shots_prefix.color_fg)
    end)

    it('should have file.stats_notification.enabled', function()
      assert.is_table(ext_config.DEFAULTS.file.stats_notification)
      assert.is_true(ext_config.DEFAULTS.file.stats_notification.enabled)
    end)
  end)

  describe('fix_config', function()
    local tmp_path

    before_each(function()
      tmp_path = os.tmpname()
    end)

    after_each(function()
      os.remove(tmp_path)
    end)

    it('should strip invalid keys', function()
      local content = 'file:\n  open_shots:\n    color_bg: "#ff0000"\n    bogus_key: 123\n  invalid_section:\n    foo: bar'
      local f = io.open(tmp_path, 'w')
      f:write(content)
      f:close()
      local removed, added = ext_config.fix_config(tmp_path, false)
      assert.equals(2, removed) -- bogus_key + foo
      assert.equals(0, added)
      -- Verify the file was rewritten without invalid keys
      local f2 = io.open(tmp_path, 'r')
      local result = f2:read('*a')
      f2:close()
      assert.matches('color_bg', result)
      assert.is_nil(result:match('bogus_key'))
      assert.is_nil(result:match('invalid_section'))
    end)

    it('should fill missing defaults for global config', function()
      -- Only set one value, rest should be filled
      local content = 'file:\n  open_shots:\n    color_bg: "#custom"'
      local f = io.open(tmp_path, 'w')
      f:write(content)
      f:close()
      local removed, added = ext_config.fix_config(tmp_path, true)
      assert.equals(0, removed)
      assert.is_true(added > 0) -- missing keys were added
      -- Verify file has all defaults
      local f2 = io.open(tmp_path, 'r')
      local result = f2:read('*a')
      f2:close()
      assert.matches('first_shot_of_the_day_prefix', result)
      assert.matches('closed_shots_prefix', result)
      assert.matches('#custom', result) -- user value preserved
    end)

    it('should not fill missing defaults for local config', function()
      local content = 'file:\n  open_shots:\n    color_bg: "#custom"'
      local f = io.open(tmp_path, 'w')
      f:write(content)
      f:close()
      local removed, added = ext_config.fix_config(tmp_path, false)
      assert.equals(0, removed)
      assert.equals(0, added) -- local config: no filling
    end)

    it('should return 0,0 for valid complete config', function()
      local content = ext_config.serialize_yaml(ext_config.DEFAULTS)
      local f = io.open(tmp_path, 'w')
      f:write(content)
      f:close()
      local removed, added = ext_config.fix_config(tmp_path, true)
      assert.equals(0, removed)
      assert.equals(0, added)
    end)
  end)
end)
