-- Tests for shooter.core.files
local files = require('shooter.core.files')
local utils = require('shooter.utils')

describe('shooter.core.files', function()
  local test_root = '/tmp/shooter_files_test'
  local original_get_git_root

  before_each(function()
    os.execute('rm -rf ' .. test_root)
    os.execute('mkdir -p ' .. test_root)
    original_get_git_root = files.get_git_root
    files.get_git_root = function() return test_root end
  end)

  after_each(function()
    os.execute('rm -rf ' .. test_root)
    files.get_git_root = original_get_git_root
  end)

  describe('create_file', function()
    it('creates file with slugified title at shotfiles root', function()
      local path = files.create_file('My Feature', '', '', nil)
      assert.is_truthy(path)
      assert.equals(test_root .. '/.hal/shooter/shotfiles/my-feature.md', path)
      assert.equals(1, vim.fn.filereadable(path))
    end)

    it('splits subpath out of title into nested folders', function()
      local path = files.create_file('some/test/title haaa', '', '', nil)
      assert.is_truthy(path)
      assert.equals(
        test_root .. '/.hal/shooter/shotfiles/some/test/title-haaa.md',
        path
      )
      assert.equals(1, vim.fn.filereadable(path))

      local content = utils.read_file(path)
      assert.equals('# some/test/title-haaa', content:match('^([^\n]+)'))
    end)

    it('handles single-level subpath in title', function()
      local path = files.create_file('sub/thing', '', '', nil)
      assert.equals(
        test_root .. '/.hal/shooter/shotfiles/sub/thing.md',
        path
      )
      assert.equals(1, vim.fn.filereadable(path))
    end)

    it('leaves bare title untouched', function()
      local path = files.create_file('plain title', '', '', nil)
      assert.equals(
        test_root .. '/.hal/shooter/shotfiles/plain-title.md',
        path
      )
    end)
  end)
end)
