-- Tests for shooter.providers.gemini file-send behavior

describe('providers.gemini', function()
  local gemini
  local original_jobstart
  local original_jobwait

  before_each(function()
    package.loaded['shooter.providers.gemini'] = nil
    gemini = require('shooter.providers.gemini')
    original_jobstart = vim.fn.jobstart
    original_jobwait = vim.fn.jobwait
  end)

  after_each(function()
    vim.fn.jobstart = original_jobstart
    vim.fn.jobwait = original_jobwait
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

  it('sends literal filepath without @ prefix', function()
    local captured_cmd
    vim.fn.jobstart = function(args)
      captured_cmd = args[3]
      return 1
    end
    vim.fn.jobwait = function()
      return {0}
    end

    local ok, err = gemini.send_file_reference('%1', '/outside/shot-1.md')

    assert.is_true(ok)
    assert.is_nil(err)
    assert.is_truthy(captured_cmd:match("tmux send%-keys %-t %%1 %-l '/outside/shot%-1%.md'"))
    assert.is_falsy(captured_cmd:match("@/outside/shot%-1%.md"))
  end)
end)
