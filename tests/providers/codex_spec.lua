-- Tests for shooter.providers.codex file-reference behavior

describe('providers.codex', function()
  local original_files
  local original_utils
  local original_send

  before_each(function()
    original_files = package.loaded['shooter.core.files']
    original_utils = package.loaded['shooter.utils']
    original_send = package.loaded['shooter.tmux.send']
  end)

  after_each(function()
    package.loaded['shooter.core.files'] = original_files
    package.loaded['shooter.utils'] = original_utils
    package.loaded['shooter.tmux.send'] = original_send
  end)

  it('sends original path when file is inside workspace', function()
    local sent_path
    local write_called = false

    package.loaded['shooter.core.files'] = {
      get_git_root = function() return '/repo' end,
    }
    package.loaded['shooter.utils'] = {
      read_file = function() return nil, 'not expected' end,
      ensure_dir = function() end,
      write_file = function()
        write_called = true
        return false, 'not expected'
      end,
    }
    package.loaded['shooter.tmux.send'] = {
      send_file_reference = function(_, filepath)
        sent_path = filepath
        return true, nil
      end,
    }

    local codex = require('shooter.providers.codex')
    local ok = codex.send_file_reference('%1', '/repo/.shooter.nvim/bullets/shot-1.md')

    assert.is_true(ok)
    assert.are.equal('/repo/.shooter.nvim/bullets/shot-1.md', sent_path)
    assert.is_false(write_called)
  end)

  it('copies external file into workspace before sending', function()
    local ensured_dir
    local write_path
    local write_content
    local sent_path

    package.loaded['shooter.core.files'] = {
      get_git_root = function() return '/repo' end,
    }
    package.loaded['shooter.utils'] = {
      read_file = function(filepath)
        assert.are.equal('/outside/shot-1.md', filepath)
        return '# shot 1\ncontent\n'
      end,
      ensure_dir = function(dir)
        ensured_dir = dir
      end,
      write_file = function(filepath, content)
        write_path = filepath
        write_content = content
        return true, nil
      end,
    }
    package.loaded['shooter.tmux.send'] = {
      send_file_reference = function(_, filepath)
        sent_path = filepath
        return true, nil
      end,
    }

    local codex = require('shooter.providers.codex')
    local ok = codex.send_file_reference('%1', '/outside/shot-1.md')

    assert.is_true(ok)
    assert.are.equal('/repo/.shooter.nvim/bullets', ensured_dir)
    assert.are.equal('/repo/.shooter.nvim/bullets/shot-1.md', write_path)
    assert.are.equal('# shot 1\ncontent\n', write_content)
    assert.are.equal('/repo/.shooter.nvim/bullets/shot-1.md', sent_path)
  end)
end)
