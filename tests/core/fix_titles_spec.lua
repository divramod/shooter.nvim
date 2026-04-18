-- Tests for shooter.core.fix_titles
local fix_titles = require('shooter.core.fix_titles')
local files = require('shooter.core.files')
local utils = require('shooter.utils')

describe('shooter.core.fix_titles', function()
  local test_root = '/tmp/shooter_fix_titles_test'
  local shotfiles_dir = test_root .. '/.hal/util/shooter/shotfiles'

  before_each(function()
    os.execute('rm -rf ' .. test_root)
    os.execute('mkdir -p ' .. shotfiles_dir)
  end)

  after_each(function()
    os.execute('rm -rf ' .. test_root)
  end)

  describe('read_h1', function()
    it('returns trimmed title from first line', function()
      assert.equals('foo', fix_titles.read_h1('# foo\n\n## shot 1\n'))
    end)

    it('returns title with slashes unchanged', function()
      assert.equals('some/test/foo', fix_titles.read_h1('# some/test/foo\n\n'))
    end)

    it('trims trailing whitespace', function()
      assert.equals('foo', fix_titles.read_h1('# foo   \n\n'))
    end)

    it('finds H1 on later line', function()
      assert.equals('bar', fix_titles.read_h1('\n\n# bar\n'))
    end)

    it('returns nil when no H1 within first 50 lines', function()
      assert.is_nil(fix_titles.read_h1('## shot 1\n\ncontent\n'))
    end)

    it('returns nil for empty content', function()
      assert.is_nil(fix_titles.read_h1(''))
    end)

    it('returns nil for nil content', function()
      assert.is_nil(fix_titles.read_h1(nil))
    end)

    it('ignores H2 and deeper headings', function()
      assert.is_nil(fix_titles.read_h1('## shot 1\n### sub\n'))
    end)
  end)

  describe('files.title_from_path', function()
    it('returns filename only for root shotfiles', function()
      assert.equals('feats', files.title_from_path('/repo/.hal/util/shooter/shotfiles/feats.md'))
    end)

    it('returns path/name for subfolder shotfiles', function()
      assert.equals('some/test/shotfile',
        files.title_from_path('/repo/.hal/util/shooter/shotfiles/some/test/shotfile.md'))
    end)

    it('handles project shotfiles (projects/X/.hal/util/shooter/shotfiles)', function()
      assert.equals('foo/bar',
        files.title_from_path('/repo/projects/myproj/.hal/util/shooter/shotfiles/foo/bar.md'))
    end)

    it('strips .md extension', function()
      local title = files.title_from_path('/repo/.hal/util/shooter/shotfiles/a/b.md')
      assert.is_nil(title:find('%.md'))
    end)
  end)

  describe('fix_title_in_file', function()
    it('fixes a wrong title to the canonical path form', function()
      local filepath = shotfiles_dir .. '/foo.md'
      utils.write_file(filepath, '# wrong title\n\n## shot 1\ncontent\n')

      local changed, old, new = fix_titles.fix_title_in_file(filepath)
      assert.is_true(changed)
      assert.equals('wrong title', old)
      assert.equals('foo', new)

      local content = utils.read_file(filepath)
      assert.truthy(content:find('^# foo\n'))
      assert.truthy(content:find('## shot 1'))
      assert.truthy(content:find('content'))
    end)

    it('fixes a subfolder shotfile to include the path', function()
      local subdir = shotfiles_dir .. '/some/test'
      os.execute('mkdir -p ' .. subdir)
      local filepath = subdir .. '/shotfile.md'
      utils.write_file(filepath, '# shotfile\n\n## shot 1\n')

      local changed, old, new = fix_titles.fix_title_in_file(filepath)
      assert.is_true(changed)
      assert.equals('shotfile', old)
      assert.equals('some/test/shotfile', new)

      local content = utils.read_file(filepath)
      assert.truthy(content:find('^# some/test/shotfile\n'))
    end)

    it('leaves a correct title unchanged', function()
      local filepath = shotfiles_dir .. '/feats.md'
      local original = '# feats\n\n## shot 1\nbody\n'
      utils.write_file(filepath, original)

      local changed, old, new = fix_titles.fix_title_in_file(filepath)
      assert.is_false(changed)
      assert.equals('feats', old)
      assert.equals('feats', new)
      assert.equals(original, utils.read_file(filepath))
    end)

    it('prepends a title if the file has no H1', function()
      local filepath = shotfiles_dir .. '/newfile.md'
      utils.write_file(filepath, '## shot 1\nbody\n')

      local changed, old, new = fix_titles.fix_title_in_file(filepath)
      assert.is_true(changed)
      assert.is_nil(old)
      assert.equals('newfile', new)

      local content = utils.read_file(filepath)
      assert.truthy(content:find('^# newfile\n\n## shot 1'))
    end)

    it('preserves the rest of file content', function()
      local filepath = shotfiles_dir .. '/keep.md'
      utils.write_file(filepath,
        '# old\n\n## shot 1\nline A\n\n## x shot 2\nline B\n')

      fix_titles.fix_title_in_file(filepath)
      local content = utils.read_file(filepath)
      assert.truthy(content:find('## shot 1'))
      assert.truthy(content:find('line A'))
      assert.truthy(content:find('## x shot 2'))
      assert.truthy(content:find('line B'))
    end)

    it('handles titles with slashes without escaping', function()
      local subdir = shotfiles_dir .. '/a/b/c'
      os.execute('mkdir -p ' .. subdir)
      local filepath = subdir .. '/d.md'
      utils.write_file(filepath, '# wrong\n')

      fix_titles.fix_title_in_file(filepath)
      local content = utils.read_file(filepath)
      assert.truthy(content:find('^# a/b/c/d\n'))
    end)

    it('returns an error for unreadable paths', function()
      local changed, old, new, err = fix_titles.fix_title_in_file('/tmp/does-not-exist.md')
      assert.is_false(changed)
      assert.is_nil(old)
      assert.is_nil(new)
      assert.truthy(err)
    end)
  end)

  describe('collect_shotfiles', function()
    it('includes files in the root shotfiles dir', function()
      utils.write_file(shotfiles_dir .. '/a.md', '# a\n')
      os.execute('mkdir -p ' .. shotfiles_dir .. '/sub')
      utils.write_file(shotfiles_dir .. '/sub/b.md', '# sub/b\n')

      local found = fix_titles.collect_shotfiles(test_root)
      table.sort(found)
      assert.equals(2, #found)
      assert.equals(shotfiles_dir .. '/a.md', found[1])
      assert.equals(shotfiles_dir .. '/sub/b.md', found[2])
    end)

    it('includes project shotfiles dirs', function()
      utils.write_file(shotfiles_dir .. '/root.md', '# root\n')
      local proj_dir = test_root .. '/projects/myproj/.hal/util/shooter/shotfiles'
      os.execute('mkdir -p ' .. proj_dir)
      utils.write_file(proj_dir .. '/proj.md', '# proj\n')

      local found = fix_titles.collect_shotfiles(test_root)
      local names = {}
      for _, path in ipairs(found) do
        table.insert(names, path:match('([^/]+%.md)$'))
      end
      table.sort(names)
      assert.same({ 'proj.md', 'root.md' }, names)
    end)

    it('returns empty list when shotfiles dir is absent', function()
      os.execute('rm -rf ' .. shotfiles_dir)
      local found = fix_titles.collect_shotfiles(test_root)
      assert.equals(0, #found)
    end)
  end)

  describe('fix_all_titles', function()
    it('fixes only mismatched files and reports stats', function()
      utils.write_file(shotfiles_dir .. '/correct.md', '# correct\n\n## shot 1\n')
      utils.write_file(shotfiles_dir .. '/wrong.md', '# stale\n\n## shot 1\n')
      os.execute('mkdir -p ' .. shotfiles_dir .. '/domain')
      utils.write_file(shotfiles_dir .. '/domain/leaf.md', '# leaf\n\n## shot 1\n')

      local stats = fix_titles.fix_all_titles(test_root)
      assert.equals(3, stats.checked)
      assert.equals(2, stats.fixed)
      assert.equals(0, #stats.errors)

      assert.equals('# correct',
        utils.read_file(shotfiles_dir .. '/correct.md'):match('^([^\n]+)'))
      assert.equals('# wrong',
        utils.read_file(shotfiles_dir .. '/wrong.md'):match('^([^\n]+)'))
      assert.equals('# domain/leaf',
        utils.read_file(shotfiles_dir .. '/domain/leaf.md'):match('^([^\n]+)'))
    end)

    it('is idempotent', function()
      os.execute('mkdir -p ' .. shotfiles_dir .. '/x/y')
      utils.write_file(shotfiles_dir .. '/x/y/z.md', '# wrong\n\n## shot 1\n')

      fix_titles.fix_all_titles(test_root)
      local stats = fix_titles.fix_all_titles(test_root)
      assert.equals(0, stats.fixed)
    end)
  end)

  describe('build_commit_message', function()
    it('uses a singular subject for one change', function()
      local msg = fix_titles.build_commit_message('/repo', {
        { path = '/repo/.hal/util/shooter/shotfiles/foo.md', old = 'wrong', new = 'foo' },
      })
      assert.truthy(msg:find('canonicalize 1 H1 title\n', 1, true))
      assert.truthy(msg:find('- .hal/util/shooter/shotfiles/foo.md: "wrong" %-> "foo"'))
    end)

    it('uses a plural subject for multiple changes', function()
      local msg = fix_titles.build_commit_message('/repo', {
        { path = '/repo/.hal/util/shooter/shotfiles/a.md', old = 'a0', new = 'a' },
        { path = '/repo/.hal/util/shooter/shotfiles/b/c.md', old = 'c', new = 'b/c' },
      })
      assert.truthy(msg:find('canonicalize 2 H1 titles'))
      assert.truthy(msg:find('- .hal/util/shooter/shotfiles/a.md:'))
      assert.truthy(msg:find('- .hal/util/shooter/shotfiles/b/c.md: "c" %-> "b/c"'))
    end)

    it('labels missing old titles', function()
      local msg = fix_titles.build_commit_message('/repo', {
        { path = '/repo/.hal/util/shooter/shotfiles/fresh.md', old = nil, new = 'fresh' },
      })
      assert.truthy(msg:find('%(missing%) %-> "fresh"'))
    end)
  end)

  describe('commit_fixes', function()
    local repo = '/tmp/shooter_commit_fixes_test'
    local shotfiles = repo .. '/.hal/util/shooter/shotfiles'

    local function git(...)
      local cmd = { 'git', '-C', repo }
      for _, a in ipairs({ ... }) do table.insert(cmd, a) end
      return vim.fn.system(cmd)
    end

    local function count_commits()
      local out = git('rev-list', '--count', 'HEAD')
      return tonumber(out:match('%d+')) or 0
    end

    before_each(function()
      os.execute('rm -rf ' .. repo)
      os.execute('mkdir -p ' .. shotfiles)
      vim.fn.system({ 'git', '-C', repo, 'init', '-q' })
      vim.fn.system({ 'git', '-C', repo, 'config', 'user.email', 'test@test' })
      vim.fn.system({ 'git', '-C', repo, 'config', 'user.name', 'Test' })
      vim.fn.system({ 'git', '-C', repo, 'config', 'commit.gpgsign', 'false' })
      vim.fn.system({ 'git', '-C', repo, 'commit', '--allow-empty', '-q', '-m', 'init' })
    end)

    after_each(function()
      os.execute('rm -rf ' .. repo)
    end)

    it('no-ops when changes is empty', function()
      local ok, err = fix_titles.commit_fixes(repo, {})
      assert.is_true(ok)
      assert.is_nil(err)
      assert.equals(1, count_commits())
    end)

    it('commits a fixed shotfile with descriptive message', function()
      local filepath = shotfiles .. '/foo.md'
      utils.write_file(filepath, '# foo\n\n## shot 1\n')

      local ok, err = fix_titles.commit_fixes(repo, {
        { path = filepath, old = 'wrong', new = 'foo' },
      })
      assert.is_true(ok, err)
      assert.equals(2, count_commits())

      local log = git('log', '-1', '--format=%B')
      assert.truthy(log:find('fix%(shotfiles%): canonicalize 1 H1 title'))
      assert.truthy(log:find('- .hal/util/shooter/shotfiles/foo.md: "wrong" %-> "foo"'))
    end)

    it('commits multiple fixed files in one commit', function()
      os.execute('mkdir -p ' .. shotfiles .. '/sub')
      local a = shotfiles .. '/a.md'
      local b = shotfiles .. '/sub/b.md'
      utils.write_file(a, '# a\n')
      utils.write_file(b, '# sub/b\n')

      local ok = fix_titles.commit_fixes(repo, {
        { path = a, old = 'x', new = 'a' },
        { path = b, old = 'y', new = 'sub/b' },
      })
      assert.is_true(ok)
      assert.equals(2, count_commits())

      local files_in_commit = git('show', '--name-only', '--format=', 'HEAD')
      assert.truthy(files_in_commit:find('a.md'))
      assert.truthy(files_in_commit:find('sub/b.md'))

      local subject = git('log', '-1', '--format=%s')
      assert.truthy(subject:find('canonicalize 2 H1 titles'))
    end)

    it('does not include unrelated staged changes', function()
      local shot = shotfiles .. '/foo.md'
      local other = repo .. '/unrelated.txt'
      utils.write_file(shot, '# foo\n')
      utils.write_file(other, 'hello\n')
      vim.fn.system({ 'git', '-C', repo, 'add', 'unrelated.txt' })

      local ok = fix_titles.commit_fixes(repo, {
        { path = shot, old = 'wrong', new = 'foo' },
      })
      assert.is_true(ok)

      local files_in_commit = git('show', '--name-only', '--format=', 'HEAD')
      assert.truthy(files_in_commit:find('foo.md'))
      assert.is_nil(files_in_commit:find('unrelated.txt'))

      local status = git('status', '--porcelain')
      assert.truthy(status:find('A%s+unrelated.txt') or status:find('unrelated.txt'))
    end)

    it('skips paths that are outside git_root', function()
      local ok = fix_titles.commit_fixes(repo, {
        { path = '/tmp/not-in-repo/x.md', old = 'a', new = 'b' },
      })
      assert.is_true(ok)
      assert.equals(1, count_commits())
    end)

    it('reports error if git_root is not a git repo', function()
      local not_repo = '/tmp/shooter_not_a_repo_' .. os.time()
      os.execute('mkdir -p ' .. not_repo .. '/.hal/util/shooter/shotfiles')
      utils.write_file(not_repo .. '/.hal/util/shooter/shotfiles/foo.md', '# foo\n')

      local ok, err = fix_titles.commit_fixes(not_repo, {
        { path = not_repo .. '/.hal/util/shooter/shotfiles/foo.md', old = 'x', new = 'foo' },
      })
      assert.is_false(ok)
      assert.truthy(err)

      os.execute('rm -rf ' .. not_repo)
    end)
  end)

  describe('fix_all_titles + commit_fixes end to end', function()
    local repo = '/tmp/shooter_fix_e2e_test'
    local shotfiles = repo .. '/.hal/util/shooter/shotfiles'

    before_each(function()
      os.execute('rm -rf ' .. repo)
      os.execute('mkdir -p ' .. shotfiles .. '/sub')
      vim.fn.system({ 'git', '-C', repo, 'init', '-q' })
      vim.fn.system({ 'git', '-C', repo, 'config', 'user.email', 'test@test' })
      vim.fn.system({ 'git', '-C', repo, 'config', 'user.name', 'Test' })
      vim.fn.system({ 'git', '-C', repo, 'config', 'commit.gpgsign', 'false' })
      utils.write_file(shotfiles .. '/foo.md', '# wrong\n')
      utils.write_file(shotfiles .. '/sub/bar.md', '# bar\n')
      vim.fn.system({ 'git', '-C', repo, 'add', '.' })
      vim.fn.system({ 'git', '-C', repo, 'commit', '-q', '-m', 'seed' })
    end)

    after_each(function()
      os.execute('rm -rf ' .. repo)
    end)

    it('fixes and commits the changed shotfiles', function()
      local stats = fix_titles.fix_all_titles(repo)
      assert.equals(2, stats.fixed)

      local ok, err = fix_titles.commit_fixes(repo, stats.changes)
      assert.is_true(ok, err)

      local foo_content = utils.read_file(shotfiles .. '/foo.md')
      local bar_content = utils.read_file(shotfiles .. '/sub/bar.md')
      assert.equals('# foo', foo_content:match('^([^\n]+)'))
      assert.equals('# sub/bar', bar_content:match('^([^\n]+)'))

      local log = vim.fn.system({ 'git', '-C', repo, 'log', '--oneline' })
      local count = 0
      for _ in log:gmatch('[^\n]+') do count = count + 1 end
      assert.equals(2, count)  -- seed + our auto-commit
    end)

    it('leaves the tree clean after auto-commit', function()
      local stats = fix_titles.fix_all_titles(repo)
      fix_titles.commit_fixes(repo, stats.changes)

      local status = vim.fn.system({ 'git', '-C', repo, 'status', '--porcelain' })
      assert.equals('', status)
    end)
  end)
end)
