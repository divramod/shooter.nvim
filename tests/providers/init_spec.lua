-- Tests for shooter.nvim providers module
local providers = require('shooter.providers')

describe('providers', function()
  describe('registration', function()
    it('should have claude provider registered', function()
      local claude = providers.get_provider('claude')
      assert.is_not_nil(claude)
      assert.equals('claude', claude.name)
      assert.equals('Claude', claude.display_name)
      assert.equals('claude', claude.process_pattern)
    end)

    it('should have opencode provider registered', function()
      local opencode = providers.get_provider('opencode')
      assert.is_not_nil(opencode)
      assert.equals('opencode', opencode.name)
      assert.equals('OpenCode', opencode.display_name)
      assert.equals('opencode', opencode.process_pattern)
    end)
  end)

  describe('get_all_process_patterns', function()
    it('should return patterns for all registered providers', function()
      local patterns = providers.get_all_process_patterns()
      assert.is_table(patterns)
      assert.is_true(#patterns >= 2)  -- At least claude and opencode

      local has_claude = false
      local has_opencode = false
      for _, pattern in ipairs(patterns) do
        if pattern == 'claude' then has_claude = true end
        if pattern == 'opencode' then has_opencode = true end
      end

      assert.is_true(has_claude, 'Should have claude pattern')
      assert.is_true(has_opencode, 'Should have opencode pattern')
    end)
  end)

  describe('get_default_provider', function()
    it('should return claude as default provider', function()
      local default = providers.get_default_provider()
      assert.is_not_nil(default)
      assert.equals('claude', default.name)
    end)
  end)

  describe('provider interface', function()
    it('claude provider should have required methods', function()
      local claude = providers.get_provider('claude')
      assert.is_function(claude.send_file_reference)
      assert.is_function(claude.send_text)
      assert.is_function(claude.build_shot_message)
      assert.is_function(claude.build_multishot_message)
      assert.is_function(claude.get_create_command)
      assert.is_function(claude.supports_auto_create)
    end)

    it('opencode provider should have required methods', function()
      local opencode = providers.get_provider('opencode')
      assert.is_function(opencode.send_file_reference)
      assert.is_function(opencode.send_text)
      assert.is_function(opencode.build_shot_message)
      assert.is_function(opencode.build_multishot_message)
      assert.is_function(opencode.get_create_command)
      assert.is_function(opencode.supports_auto_create)
    end)
  end)
end)
