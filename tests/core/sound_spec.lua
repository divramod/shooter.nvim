-- Test suite for shooter.sound module
local sound = require('shooter.sound')
local config = require('shooter.config')

describe('sound module', function()
  local original_config

  before_each(function()
    -- Save original config
    original_config = {
      enabled = config.get('sound.enabled'),
      file = config.get('sound.file'),
      volume = config.get('sound.volume'),
    }
  end)

  after_each(function()
    -- Restore original config
    config.set('sound.enabled', original_config.enabled)
    config.set('sound.file', original_config.file)
    config.set('sound.volume', original_config.volume)
  end)

  describe('play', function()
    it('does nothing when sound is disabled', function()
      config.set('sound.enabled', false)
      -- Should not throw any errors
      sound.play()
    end)

    it('does nothing when file is empty', function()
      config.set('sound.enabled', true)
      config.set('sound.file', '')
      -- Should not throw any errors
      sound.play()
    end)

    it('does nothing when file does not exist', function()
      config.set('sound.enabled', true)
      config.set('sound.file', '/nonexistent/path/sound.aiff')
      -- Should not throw any errors
      sound.play()
    end)
  end)

  describe('play_file', function()
    it('does nothing when filepath is empty', function()
      -- Should not throw any errors
      sound.play_file('')
    end)

    it('does nothing when filepath is nil', function()
      -- Should not throw any errors
      sound.play_file(nil)
    end)

    it('does nothing when file does not exist', function()
      -- Should not throw any errors
      sound.play_file('/nonexistent/path/sound.aiff')
    end)
  end)

  describe('test', function()
    it('echoes message when sound is disabled', function()
      config.set('sound.enabled', false)
      -- Mock utils.echo
      local original_echo = require('shooter.utils').echo
      local echo_called = false
      require('shooter.utils').echo = function(msg)
        echo_called = true
        assert.is_truthy(msg:match('disabled'))
      end

      sound.test()

      require('shooter.utils').echo = original_echo
      assert.is_true(echo_called)
    end)

    it('echoes message when sound file is empty', function()
      config.set('sound.enabled', true)
      config.set('sound.file', '')

      local original_echo = require('shooter.utils').echo
      local echo_called = false
      require('shooter.utils').echo = function(msg)
        echo_called = true
        assert.is_truthy(msg:match('No sound file'))
      end

      sound.test()

      require('shooter.utils').echo = original_echo
      assert.is_true(echo_called)
    end)
  end)
end)
