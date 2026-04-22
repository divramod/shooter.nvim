-- Tests for shooter.core.files
local files = require('shooter.core.files')
local utils = require('shooter.utils')
local ext_config = require('shooter.core.ext_config')
local storage = require('shooter.session.storage')

-- Capture real get_git_root before the outer describe monkey-patches it, so
-- nested specs can exercise the true main-worktree resolution.
local real_get_git_root = files.get_git_root

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

  describe('open_shotfile', function()
    local main_root = '/tmp/shooter_open_main'
    local wt_root = '/tmp/shooter_open_wt_1'
    local shotfile
    local prev_cwd

    before_each(function()
      prev_cwd = vim.fn.getcwd()
      os.execute('rm -rf ' .. main_root .. ' ' .. wt_root)
      os.execute('mkdir -p ' .. main_root .. '/.hal/util/shooter/shotfiles')
      os.execute('git -C ' .. main_root .. ' init -q -b main')
      os.execute('git -C ' .. main_root .. ' -c user.email=t@t -c user.name=t '
        .. 'commit -q --allow-empty -m init')
      os.execute('git -C ' .. main_root .. ' worktree add -q -b other '
        .. wt_root .. ' >/dev/null 2>&1')
      shotfile = main_root .. '/.hal/util/shooter/shotfiles/thing.md'
      local f = io.open(shotfile, 'w'); f:write('# thing\n'); f:close()
    end)

    after_each(function()
      vim.cmd('cd ' .. vim.fn.fnameescape(prev_cwd))
      vim.cmd('silent! %bdelete!')
      os.execute('git -C ' .. main_root .. ' worktree remove -f ' .. wt_root
        .. ' >/dev/null 2>&1')
      os.execute('rm -rf ' .. main_root .. ' ' .. wt_root)
    end)

    it('cds to the file git root when cwd differs', function()
      vim.cmd('cd ' .. wt_root)
      files.open_shotfile(shotfile)
      assert.truthy(vim.fn.getcwd():match('shooter_open_main$'))
      assert.truthy(vim.fn.expand('%:p'):match('thing%.md$'))
    end)

    it('leaves cwd unchanged when file is already in current root', function()
      vim.cmd('cd ' .. main_root)
      local before = vim.fn.getcwd()
      files.open_shotfile(shotfile)
      assert.equals(before, vim.fn.getcwd())
      assert.truthy(vim.fn.expand('%:p'):match('thing%.md$'))
    end)

    it('is a no-op for nil or empty path', function()
      vim.cmd('cd ' .. wt_root)
      local before = vim.fn.getcwd()
      files.open_shotfile(nil)
      files.open_shotfile('')
      assert.equals(before, vim.fn.getcwd())
    end)
  end)

  describe('get_git_root (main-worktree-oriented)', function()
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
      -- Outer describe monkey-patches get_git_root; restore the real one.
      files.get_git_root = real_get_git_root
    end)

    after_each(function()
      vim.cmd('cd ' .. vim.fn.fnameescape(prev_cwd))
      os.execute('git -C ' .. main_root .. ' worktree remove -f ' .. wt_root
        .. ' >/dev/null 2>&1')
      os.execute('rm -rf ' .. main_root .. ' ' .. wt_root)
    end)

    it('returns the main worktree path when cwd is a worktree', function()
      vim.cmd('cd ' .. wt_root)
      local root = files.get_git_root()
      assert.truthy(root)
      assert.truthy(root:match('shooter_main_wt$'))
    end)

    it('returns the main worktree path when cwd is main', function()
      vim.cmd('cd ' .. main_root)
      local root = files.get_git_root()
      assert.truthy(root)
      assert.truthy(root:match('shooter_main_wt$'))
    end)

    it('get_cwd_git_root returns the current worktree toplevel', function()
      vim.cmd('cd ' .. wt_root)
      local root = files.get_cwd_git_root()
      assert.truthy(root)
      assert.truthy(root:match('shooter_wt_1$'))
    end)
  end)

  describe('find_last_file stale-state rejection', function()
    local base = vim.fn.expand('~') .. '/.cache/shooter_stale_test'
    local main_root = base .. '/main'
    local wt_root = base .. '/wt_1'
    local prev_cwd
    local persisted_path
    local original_persisted

    before_each(function()
      prev_cwd = vim.fn.getcwd()
      os.execute('rm -rf ' .. base)
      os.execute('mkdir -p ' .. main_root .. '/.hal/util/shooter/shotfiles')
      os.execute('git -C ' .. main_root .. ' init -q -b main')
      os.execute('git -C ' .. main_root .. ' -c user.email=t@t -c user.name=t '
        .. 'commit -q --allow-empty -m init')
      os.execute('git -C ' .. main_root .. ' worktree add -q -b other '
        .. wt_root .. ' >/dev/null 2>&1')
      os.execute('mkdir -p ' .. wt_root .. '/.hal/util/shooter/shotfiles')
      -- Main shotfile exists so mtime fallback has something to return
      local main_file = main_root .. '/.hal/util/shooter/shotfiles/main-only.md'
      local mf = io.open(main_file, 'w'); mf:write('# main-only\n'); mf:close()
      -- Stale worktree shotfile persisted from before the fix
      local stale_file = wt_root .. '/.hal/util/shooter/shotfiles/stale.md'
      local sf = io.open(stale_file, 'w'); sf:write('# stale\n'); sf:close()

      files.get_git_root = real_get_git_root
      vim.cmd('cd ' .. main_root)
      local slug = storage.get_repo_slug(real_get_git_root()):gsub('/', '_')
      persisted_path = ext_config.last_shotfile_path(slug)
      -- Back up any real persisted file, write the stale worktree path
      local b = io.open(persisted_path, 'r')
      if b then original_persisted = b:read('*a'); b:close() end
      utils.ensure_dir(utils.get_dirname(persisted_path))
      local pf = io.open(persisted_path, 'w')
      pf:write(stale_file); pf:close()
    end)

    after_each(function()
      vim.cmd('cd ' .. vim.fn.fnameescape(prev_cwd))
      if original_persisted then
        local pf = io.open(persisted_path, 'w'); pf:write(original_persisted); pf:close()
      else
        os.remove(persisted_path)
      end
      original_persisted = nil
      os.execute('git -C ' .. main_root .. ' worktree remove -f ' .. wt_root
        .. ' >/dev/null 2>&1')
      os.execute('rm -rf ' .. base)
    end)

    it('rejects a persisted worktree-path shotfile and falls back to main', function()
      vim.cmd('cd ' .. main_root)
      local last = files.find_last_file()
      assert.truthy(last)
      assert.truthy(last:match('main%-only%.md$'),
        'expected main-only.md, got: ' .. tostring(last))
    end)

    it('from a worktree cwd, still returns the main-path shotfile', function()
      vim.cmd('cd ' .. wt_root)
      local last = files.find_last_file()
      assert.truthy(last)
      assert.truthy(last:match('main%-only%.md$'),
        'expected main-only.md, got: ' .. tostring(last))
    end)
  end)
end)
