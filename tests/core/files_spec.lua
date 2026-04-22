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
      assert.equals(test_root .. '/.hal/util/shooter/shotfiles/my-feature.md', path)
      assert.equals(1, vim.fn.filereadable(path))
    end)

    it('splits subpath out of title into nested folders', function()
      local path = files.create_file('some/test/title haaa', '', '', nil)
      assert.is_truthy(path)
      assert.equals(
        test_root .. '/.hal/util/shooter/shotfiles/some/test/title-haaa.md',
        path
      )
      assert.equals(1, vim.fn.filereadable(path))

      local content = utils.read_file(path)
      assert.equals('# some/test/title-haaa', content:match('^([^\n]+)'))
    end)

    it('handles single-level subpath in title', function()
      local path = files.create_file('sub/thing', '', '', nil)
      assert.equals(
        test_root .. '/.hal/util/shooter/shotfiles/sub/thing.md',
        path
      )
      assert.equals(1, vim.fn.filereadable(path))
    end)

    it('leaves bare title untouched', function()
      local path = files.create_file('plain title', '', '', nil)
      assert.equals(
        test_root .. '/.hal/util/shooter/shotfiles/plain-title.md',
        path
      )
    end)
  end)

  describe('get_file_git_root', function()
    local repo_root = '/tmp/shooter_files_git_test'

    before_each(function()
      os.execute('rm -rf ' .. repo_root)
      os.execute('mkdir -p ' .. repo_root .. '/sub')
      os.execute('git -C ' .. repo_root .. ' init -q')
      os.execute('touch ' .. repo_root .. '/sub/file.md')
    end)

    after_each(function()
      os.execute('rm -rf ' .. repo_root)
    end)

    it('returns the git toplevel for a file path', function()
      local root = files.get_file_git_root(repo_root .. '/sub/file.md')
      -- Resolve /private/tmp vs /tmp on macOS
      assert.truthy(root)
      assert.truthy(root:match('shooter_files_git_test$'))
    end)

    it('returns nil for a path outside any git repo', function()
      os.execute('mkdir -p /tmp/shooter_not_a_repo_xyz')
      os.execute('touch /tmp/shooter_not_a_repo_xyz/foo.md')
      local root = files.get_file_git_root('/tmp/shooter_not_a_repo_xyz/foo.md')
      os.execute('rm -rf /tmp/shooter_not_a_repo_xyz')
      assert.is_nil(root)
    end)

    it('returns nil for nil or empty input', function()
      assert.is_nil(files.get_file_git_root(nil))
      assert.is_nil(files.get_file_git_root(''))
    end)
  end)

  describe('get_main_git_root', function()
    local main_root = '/tmp/shooter_main_wt'
    local wt_root = '/tmp/shooter_wt_1'
    local prev_cwd

    before_each(function()
      prev_cwd = vim.fn.getcwd()
      os.execute('rm -rf ' .. main_root .. ' ' .. wt_root)
      os.execute('mkdir -p ' .. main_root)
      os.execute('git -C ' .. main_root .. ' init -q -b main')
      os.execute('git -C ' .. main_root .. ' -c user.email=t@t -c user.name=t '
        .. 'commit -q --allow-empty -m init')
      os.execute('git -C ' .. main_root .. ' worktree add -q -b other '
        .. wt_root .. ' >/dev/null 2>&1')
    end)

    after_each(function()
      vim.cmd('cd ' .. vim.fn.fnameescape(prev_cwd))
      os.execute('git -C ' .. main_root .. ' worktree remove -f ' .. wt_root
        .. ' >/dev/null 2>&1')
      os.execute('rm -rf ' .. main_root .. ' ' .. wt_root)
    end)

    it('returns the main worktree path when cwd is a worktree', function()
      vim.cmd('cd ' .. wt_root)
      local root = files.get_main_git_root()
      assert.truthy(root)
      assert.truthy(root:match('shooter_main_wt$'))
    end)

    it('returns the main worktree path when cwd is main', function()
      vim.cmd('cd ' .. main_root)
      local root = files.get_main_git_root()
      assert.truthy(root)
      assert.truthy(root:match('shooter_main_wt$'))
    end)
  end)
end)
