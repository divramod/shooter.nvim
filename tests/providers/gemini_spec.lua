-- Tests for shooter.providers.gemini file-send behavior

describe('providers.gemini', function()
  local gemini
  local original_send
  local original_utils
  local original_jobstart
  local original_jobwait
  local original_wait
  local sent_text

  before_each(function()
    original_send = package.loaded['shooter.tmux.send']
    original_utils = package.loaded['shooter.utils']
    original_jobstart = vim.fn.jobstart
    original_jobwait = vim.fn.jobwait
    original_wait = vim.wait

    sent_text = nil
    package.loaded['shooter.tmux.send'] = {
      send_to_pane = function(_, text, _, include_escape_prep)
        sent_text = text
        assert.is_false(include_escape_prep)
        return true, nil, 0
      end,
    }
    package.loaded['shooter.utils'] = {
      read_file = function(path)
        if path == '/tmp/shot.md' then
          return '# shot\nbody\n'
        end
        return nil, 'missing'
      end,
    }

    vim.fn.jobstart = function()
      return 1
    end
    vim.fn.jobwait = function()
      return {0}
    end
    vim.wait = function()
      return true
    end

    package.loaded['shooter.providers.gemini'] = nil
    gemini = require('shooter.providers.gemini')
  end)

  after_each(function()
    package.loaded['shooter.tmux.send'] = original_send
    package.loaded['shooter.utils'] = original_utils
    vim.fn.jobstart = original_jobstart
    vim.fn.jobwait = original_jobwait
    vim.wait = original_wait
  end)

  it('returns error when pane id is missing', function()
    local ok, err = gemini.send_file_reference(nil, '/tmp/shot.md')
    assert.is_false(ok)
    assert.are.equal('No pane ID provided', err)
  end)

  it('returns error when filepath is missing', function()
    local ok, err = gemini.send_file_reference('%1', nil)
    assert.is_false(ok)
    assert.are.equal('No filepath provided', err)
  end)

  it('returns error when file cannot be read', function()
    local ok, err = gemini.send_file_reference('%1', '/tmp/missing.md')
    assert.is_false(ok)
    assert.is_truthy(err:match('Failed to read file:'))
  end)

  it('reads file and sends content to pane', function()
    local ok, err = gemini.send_file_reference('%1', '/tmp/shot.md')
    assert.is_true(ok)
    assert.is_nil(err)
    assert.are.equal('# shot\nbody\n', sent_text)
  end)
end)
