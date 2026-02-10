-- Tests for shooter.providers.gemini delegation behavior

describe('providers.gemini', function()
  local gemini
  local original_send

  before_each(function()
    original_send = package.loaded['shooter.tmux.send']
    package.loaded['shooter.tmux.send'] = {
      send_file_reference = function(pane_id, filepath)
        return pane_id == '%1' and filepath == '/tmp/shot.md', nil
      end,
      send_to_pane = function(_, _)
        return true, nil, 0
      end,
    }
    package.loaded['shooter.providers.gemini'] = nil
    gemini = require('shooter.providers.gemini')
  end)

  after_each(function()
    package.loaded['shooter.tmux.send'] = original_send
  end)

  it('delegates file reference sends to shared tmux sender', function()
    local ok, err = gemini.send_file_reference('%1', '/tmp/shot.md')
    assert.is_true(ok)
    assert.is_nil(err)
  end)
end)
