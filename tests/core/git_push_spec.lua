-- Tests for shooter.core.git_push
local git_push = require('shooter.core.git_push')
local utils = require('shooter.utils')

describe('shooter.core.git_push', function()
  local repo = '/tmp/shooter_git_push_test'
  local shooter_dir = repo .. '/.shooter'

  local function git(...)
    local cmd = { 'git', '-C', repo }
    for _, a in ipairs({ ... }) do table.insert(cmd, a) end
    return vim.fn.system(cmd)
  end

  local function count_commits()
    local out = git('rev-list', '--count', 'HEAD')
    return tonumber(out:match('%d+')) or 0
  end

  local function staged_files()
    return git('diff', '--cached', '--name-only')
  end

  before_each(function()
    os.execute('rm -rf ' .. repo)
    os.execute('mkdir -p ' .. shooter_dir)
    vim.fn.system({ 'git', '-C', repo, 'init', '-q' })
    vim.fn.system({ 'git', '-C', repo, 'config', 'user.email', 'test@test' })
    vim.fn.system({ 'git', '-C', repo, 'config', 'user.name', 'Test' })
    vim.fn.system({ 'git', '-C', repo, 'config', 'commit.gpgsign', 'false' })
    vim.fn.system({ 'git', '-C', repo, 'commit', '--allow-empty', '-q', '-m', 'init' })
  end)

  after_each(function()
    os.execute('rm -rf ' .. repo)
  end)

  describe('stage_and_commit', function()
    it('reports nothing to commit when .shooter has no changes', function()
      local ok, msg, committed = git_push.stage_and_commit(repo)
      assert.is_true(ok)
      assert.is_false(committed)
      assert.truthy(msg:find('nothing to commit'))
      assert.equals(1, count_commits())
    end)

    it('commits new files under .shooter', function()
      utils.write_file(shooter_dir .. '/config.yml', 'key: value\n')

      local ok, msg, committed = git_push.stage_and_commit(repo)
      assert.is_true(ok, msg)
      assert.is_true(committed)
      assert.equals(2, count_commits())

      local subject = git('log', '-1', '--format=%s')
      assert.truthy(subject:find('chore%(shooter%): sync'))
    end)

    it('commits modifications under .shooter', function()
      local filepath = shooter_dir .. '/config.yml'
      utils.write_file(filepath, 'key: old\n')
      git_push.stage_and_commit(repo)  -- initial commit of file
      utils.write_file(filepath, 'key: new\n')

      local ok, _, committed = git_push.stage_and_commit(repo)
      assert.is_true(ok)
      assert.is_true(committed)
      assert.equals(3, count_commits())
    end)

    it('commits deletions under .shooter', function()
      local filepath = shooter_dir .. '/gone.yml'
      utils.write_file(filepath, 'bye\n')
      git_push.stage_and_commit(repo)

      os.remove(filepath)
      local ok, _, committed = git_push.stage_and_commit(repo)
      assert.is_true(ok)
      assert.is_true(committed)

      local files_in_commit = git('show', '--name-only', '--format=', 'HEAD')
      assert.truthy(files_in_commit:find('gone.yml'))
    end)

    it('commits nested files under .shooter', function()
      os.execute('mkdir -p ' .. shooter_dir .. '/ai/context')
      utils.write_file(shooter_dir .. '/ai/context/memory.md', '# memory\n')

      local ok, _, committed = git_push.stage_and_commit(repo)
      assert.is_true(ok)
      assert.is_true(committed)

      local files_in_commit = git('show', '--name-only', '--format=', 'HEAD')
      assert.truthy(files_in_commit:find('%.shooter/ai/context/memory%.md'))
    end)

    it('leaves unrelated staged changes untouched', function()
      utils.write_file(repo .. '/other.txt', 'hello\n')
      vim.fn.system({ 'git', '-C', repo, 'add', 'other.txt' })
      utils.write_file(shooter_dir .. '/config.yml', 'key: value\n')

      local ok, _, committed = git_push.stage_and_commit(repo)
      assert.is_true(ok)
      assert.is_true(committed)

      -- other.txt should still be staged (not in the commit)
      local staged = staged_files()
      assert.truthy(staged:find('other.txt'))
      assert.is_nil(staged:find('%.shooter'))

      -- commit should contain .shooter/config.yml only
      local files_in_commit = git('show', '--name-only', '--format=', 'HEAD')
      assert.truthy(files_in_commit:find('%.shooter/config%.yml'))
      assert.is_nil(files_in_commit:find('other%.txt'))
    end)

    it('returns error when .shooter folder is missing', function()
      os.execute('rm -rf ' .. shooter_dir)
      local ok, msg, committed = git_push.stage_and_commit(repo)
      assert.is_false(ok)
      assert.is_false(committed)
      assert.truthy(msg:find('not found'))
    end)

    it('returns error when git_root is nil', function()
      local ok, msg = git_push.stage_and_commit(nil)
      assert.is_false(ok)
      assert.truthy(msg)
    end)

    it('returns error when git_root is not a git repo', function()
      local not_repo = '/tmp/shooter_git_push_not_repo'
      os.execute('rm -rf ' .. not_repo)
      os.execute('mkdir -p ' .. not_repo .. '/.shooter')
      utils.write_file(not_repo .. '/.shooter/x', 'y')

      local ok, msg = git_push.stage_and_commit(not_repo)
      assert.is_false(ok)
      assert.truthy(msg)

      os.execute('rm -rf ' .. not_repo)
    end)
  end)

  describe('run (composite)', function()
    it('short-circuits push when nothing to commit', function()
      local ok, msg = git_push.run(repo)
      assert.is_true(ok)
      assert.truthy(msg:find('nothing to commit'))
      -- No push was attempted — count stays at 1.
      assert.equals(1, count_commits())
    end)

    it('pushes after a successful commit to a local bare remote', function()
      local remote = '/tmp/shooter_git_push_remote'
      os.execute('rm -rf ' .. remote)
      vim.fn.system({ 'git', 'init', '--bare', '-q', remote })
      vim.fn.system({ 'git', '-C', repo, 'remote', 'add', 'origin', remote })
      -- Get the current branch (git default varies: main vs master)
      local branch = vim.fn.system({ 'git', '-C', repo, 'branch', '--show-current' }):gsub('%s+$', '')
      vim.fn.system({ 'git', '-C', repo, 'push', '-u', '-q', 'origin', branch })

      utils.write_file(shooter_dir .. '/new.yml', 'x: 1\n')
      local ok, msg = git_push.run(repo)
      assert.is_true(ok, msg)
      assert.truthy(msg:find('committed & pushed'))

      -- Verify remote received the commit
      local remote_log = vim.fn.system({ 'git', '-C', remote, 'log', '--format=%s' })
      assert.truthy(remote_log:find('chore%(shooter%): sync'))

      os.execute('rm -rf ' .. remote)
    end)
  end)
end)
