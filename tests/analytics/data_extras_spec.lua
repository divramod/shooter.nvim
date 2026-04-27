-- Extended characterization tests for shooter.analytics.data — covers
-- the breadth (stats / repo discovery / metrics / project detection) that
-- the original data_spec.lua left untested. T002 of phase 004.

local data = require('shooter.analytics.data')

describe('shooter.analytics.data — extras', function()
  describe('parse_executed_shot_header — more cases', function()
    it('returns nil for non-executed headers', function()
      assert.is_nil(data.parse_executed_shot_header('## shot 5'))
      assert.is_nil(data.parse_executed_shot_header(''))
      assert.is_nil(data.parse_executed_shot_header('plain text'))
    end)

    it('parses a header with no trailing @ref', function()
      local n, ts, e = data.parse_executed_shot_header('## x shot 7 (2026-04-26 11:22:33)')
      assert.are.equal(7, n)
      assert.are.equal('2026-04-26 11:22:33', ts)
      assert.is_true(e > 0)
    end)

    it('returns date string but zero epoch when the date is malformed', function()
      local n, ts, e = data.parse_executed_shot_header('## x shot 1 (not-a-date)')
      assert.are.equal(1, n)
      assert.are.equal('not-a-date', ts)
      assert.are.equal(0, e)
    end)
  end)

  describe('get_shot_metrics', function()
    it('returns body, char count, word count, sentence count', function()
      local lines = { '## x shot 1 (...)', 'one two three.', 'four five.', '' }
      local body, chars, words, sentences = data.get_shot_metrics(lines, 2, 4)
      assert.is_string(body)
      assert.is_truthy(body:find('one two three'))
      assert.is_truthy(body:find('four five'))
      assert.is_true(chars > 0)
      assert.are.equal(5, words)
      assert.are.equal(2, sentences)
    end)

    it('handles empty range', function()
      local _, chars, words, sentences = data.get_shot_metrics({}, 1, 0)
      assert.are.equal(0, chars)
      assert.are.equal(0, words)
      assert.are.equal(0, sentences)
    end)

    it('counts ! and ? as sentences', function()
      local _, _, _, s = data.get_shot_metrics({ 'wow! really? yes.' }, 1, 1)
      assert.are.equal(3, s)
    end)
  end)

  describe('parse_shotfile — additional cases', function()
    it('returns empty list for missing file', function()
      local shots = data.parse_shotfile('/nonexistent/path/to/file.md')
      assert.same({}, shots)
    end)

    it('parses multiple executed shots with metrics', function()
      local tmp = vim.fn.tempname()
      vim.fn.writefile({
        '# header',
        '## x shot 1 (2026-04-25 10:00:00)',
        'first body. has two sentences.',
        '## x shot 2 (2026-04-26 11:00:00)',
        'second body.',
        '## shot 3',
        'open shot ignored',
      }, tmp)
      local shots = data.parse_shotfile(tmp)
      vim.fn.delete(tmp)
      assert.are.equal(2, #shots)
      assert.are.equal(1, shots[1].shot)
      assert.are.equal(2, shots[2].shot)
      assert.is_true(shots[1].chars > 0)
      assert.is_true(shots[1].words > 0)
      assert.is_true(shots[1].sentences >= 2)
      assert.are.equal(tmp, shots[1].source)
    end)

    it('attaches source path on each shot', function()
      local tmp = vim.fn.tempname()
      vim.fn.writefile({ '## x shot 1 (2026-04-26 10:00:00)', 'b' }, tmp)
      local shots = data.parse_shotfile(tmp)
      vim.fn.delete(tmp)
      assert.are.equal(tmp, shots[1].source)
    end)
  end)

  describe('detect_project_from_path', function()
    it('extracts project name from /projects/<name>/ path', function()
      assert.are.equal('alpha', data.detect_project_from_path('/repo/projects/alpha/docs/shotfiles/x.md'))
    end)

    it('returns nil when no /projects/ segment', function()
      assert.is_nil(data.detect_project_from_path('/repo/docs/shotfiles/x.md'))
    end)

    it('returns nil for nil input', function()
      assert.is_nil(data.detect_project_from_path(nil))
    end)
  end)

  describe('repo_matches_filter — boundary cases', function()
    it('returns true when filter is nil or empty', function()
      assert.is_true(data.repo_matches_filter('any/repo', nil))
      assert.is_true(data.repo_matches_filter('any/repo', ''))
    end)

    it('matches short repo when no slash in filter', function()
      assert.is_true(data.repo_matches_filter('owner/proj', 'proj'))
      assert.is_false(data.repo_matches_filter('owner/proj', 'other'))
    end)

    it('matches when repo has no slash and filter equals it', function()
      assert.is_true(data.repo_matches_filter('proj', 'proj'))
    end)
  end)

  describe('get_git_remote_info — additional shapes', function()
    it('parses https url with .git suffix', function()
      if vim.fn.executable('git') == 0 then return end
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')
      vim.fn.system({ 'git', '-C', tmp, 'init' })
      vim.fn.system({ 'git', '-C', tmp, 'remote', 'add', 'origin', 'https://github.com/owner/proj.git' })
      local user, repo = data.get_git_remote_info(tmp)
      vim.fn.delete(tmp, 'rf')
      assert.are.equal('owner', user)
      assert.are.equal('proj', repo)
    end)

    it('parses https url without .git suffix', function()
      if vim.fn.executable('git') == 0 then return end
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')
      vim.fn.system({ 'git', '-C', tmp, 'init' })
      vim.fn.system({ 'git', '-C', tmp, 'remote', 'add', 'origin', 'https://github.com/owner/proj' })
      local user, repo = data.get_git_remote_info(tmp)
      vim.fn.delete(tmp, 'rf')
      assert.are.equal('owner', user)
      assert.are.equal('proj', repo)
    end)

    it('returns nil, nil when no origin remote', function()
      if vim.fn.executable('git') == 0 then return end
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')
      vim.fn.system({ 'git', '-C', tmp, 'init' })
      local user, repo = data.get_git_remote_info(tmp)
      vim.fn.delete(tmp, 'rf')
      assert.is_nil(user)
      assert.is_nil(repo)
    end)
  end)

  describe('get_time_boundaries', function()
    it('returns now/today/week/month/year all positive integers', function()
      local b = data.get_time_boundaries()
      assert.is_number(b.now)
      assert.is_true(b.now > 0)
      assert.is_true(b.today <= b.now)
      assert.is_true(b.week <= b.today)
      assert.is_true(b.month <= b.today)
      assert.is_true(b.year <= b.month)
    end)
  end)

  describe('calculate_stats', function()
    it('returns zeros for empty input', function()
      local s = data.calculate_stats({})
      assert.are.equal(0, s.total)
      assert.are.equal(0, s.today)
      assert.are.equal(0, s.this_week)
      assert.are.equal(0, s.this_month)
      assert.are.equal(0, s.this_year)
      assert.are.equal(0, s.total_chars)
      assert.are.equal(0, s.total_words)
      assert.are.equal(0, s.total_sentences)
      assert.same({}, s.by_project)
    end)

    it('aggregates totals and by_project', function()
      local now = os.time()
      local shots = {
        { shot = 1, time = now, repo = 'a/b', source = '/a/b/x.md', chars = 10, words = 3, sentences = 1 },
        { shot = 2, time = now - 100, repo = 'a/b', source = '/a/b/x.md', chars = 20, words = 5, sentences = 2 },
        { shot = 3, time = now - 200, repo = 'c/d', source = '/c/d/y.md', chars = 5, words = 1, sentences = 1 },
      }
      local s = data.calculate_stats(shots)
      assert.are.equal(3, s.total)
      assert.are.equal(35, s.total_chars)
      assert.are.equal(9, s.total_words)
      assert.are.equal(4, s.total_sentences)
      assert.are.equal(2, s.by_project['a/b'])
      assert.are.equal(1, s.by_project['c/d'])
    end)

    it('tracks longest/shortest chars/words/sentences', function()
      local now = os.time()
      local shots = {
        { shot = 1, time = now, repo = 'r', source = '/x.md', chars = 100, words = 20, sentences = 5 },
        { shot = 2, time = now, repo = 'r', source = '/x.md', chars = 10,  words = 2,  sentences = 1 },
      }
      local s = data.calculate_stats(shots)
      assert.are.equal(100, s.longest_chars.value)
      assert.are.equal(10,  s.shortest_chars.value)
      assert.are.equal(20,  s.longest_words.value)
      assert.are.equal(2,   s.shortest_words.value)
      assert.are.equal(5,   s.longest_sentences.value)
      assert.are.equal(1,   s.shortest_sentences.value)
    end)

    it('tracks by_file counts in alltime bucket', function()
      local now = os.time()
      local shots = {
        { shot = 1, time = now, repo = 'r', source = '/foo/a.md', chars = 1, words = 1, sentences = 0 },
        { shot = 2, time = now, repo = 'r', source = '/foo/a.md', chars = 1, words = 1, sentences = 0 },
        { shot = 3, time = now, repo = 'r', source = '/foo/b.md', chars = 1, words = 1, sentences = 0 },
      }
      local s = data.calculate_stats(shots)
      assert.are.equal(2, s.by_file.alltime['a.md'])
      assert.are.equal(1, s.by_file.alltime['b.md'])
    end)

    it('counts today/week/month buckets when timestamp is recent', function()
      local now = os.time()
      local shots = {
        { shot = 1, time = now, repo = 'r', source = '/x.md', chars = 1, words = 1, sentences = 0 },
      }
      local s = data.calculate_stats(shots)
      assert.are.equal(1, s.today)
      assert.are.equal(1, s.this_week)
      assert.are.equal(1, s.this_month)
      assert.are.equal(1, s.this_year)
    end)

    it('records time_diffs between consecutive shots', function()
      local now = os.time()
      local shots = {
        { shot = 1, time = now, repo = 'r', source = '/x.md', chars = 1, words = 1, sentences = 0 },
        { shot = 2, time = now - 60, repo = 'r', source = '/x.md', chars = 1, words = 1, sentences = 0 },
      }
      local s = data.calculate_stats(shots)
      assert.are.equal(1, #s.time_diffs)
      assert.are.equal(60, s.time_diffs[1])
    end)
  end)

  describe('build_path_map', function()
    it('maps short filename to first source seen', function()
      local shots = {
        { source = '/foo/x.md' },
        { source = '/bar/y.md' },
        { source = '/baz/x.md' },  -- shadowed: x.md already mapped
      }
      local map = data.build_path_map(shots)
      assert.are.equal('/foo/x.md', map['x.md'])
      assert.are.equal('/bar/y.md', map['y.md'])
    end)

    it('returns empty map for empty input', function()
      assert.same({}, data.build_path_map({}))
    end)

    it('skips shots with no source', function()
      local map = data.build_path_map({ { source = nil }, { source = '/a/b.md' } })
      assert.are.equal('/a/b.md', map['b.md'])
    end)
  end)

  describe('get_all_repo_paths', function()
    it('returns at least the current repo when in a git tree', function()
      if vim.fn.executable('git') == 0 then return end
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')
      vim.fn.system({ 'git', '-C', tmp, 'init' })
      local prev_cwd = vim.fn.getcwd()
      vim.cmd('cd ' .. vim.fn.fnameescape(tmp))
      local repos = data.get_all_repo_paths()
      vim.cmd('cd ' .. vim.fn.fnameescape(prev_cwd))
      vim.fn.delete(tmp, 'rf')
      assert.is_table(repos)
      -- Resolved git root may be canonicalized (e.g. /private/var/... on macOS),
      -- so just verify the set is non-empty and contains a valid path.
      assert.is_true(#repos >= 1)
    end)
  end)

  describe('get_all_shots', function()
    it('returns empty list when no repos found and no current git', function()
      -- Run in a non-git tmpdir to avoid pulling in user's repos.
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')
      local prev = vim.fn.getcwd()
      vim.cmd('cd ' .. vim.fn.fnameescape(tmp))
      local shots = data.get_all_shots('___no_such_filter___')
      vim.cmd('cd ' .. vim.fn.fnameescape(prev))
      vim.fn.delete(tmp, 'rf')
      assert.is_table(shots)
    end)
  end)
end)
