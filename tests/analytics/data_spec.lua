-- Test suite for shooter.analytics.data module
local data = require('shooter.analytics.data')

describe('analytics data module', function()
  describe('parse_executed_shot_header', function()
    it('parses headers with trailing metadata', function()
      local line = '## x shot 4 (2026-02-04 08:47:14) @shot-4-20260204_084714'
      local num, timestamp, epoch = data.parse_executed_shot_header(line)
      assert.are.equal(4, num)
      assert.are.equal('2026-02-04 08:47:14', timestamp)
      assert.is_truthy(epoch and epoch > 0)
    end)
  end)

  describe('parse_shotfile', function()
    it('counts executed shots with trailing metadata', function()
      local tmp = vim.fn.tempname()
      local lines = {
        '# analytics',
        '',
        '## x shot 1 (2026-02-04 08:47:14) @shot-1-20260204_084714',
        'first shot content',
        '',
        '## shot 2',
        'open shot content',
      }
      vim.fn.writefile(lines, tmp)

      local shots = data.parse_shotfile(tmp)
      vim.fn.delete(tmp)
      assert.are.equal(1, #shots)
      assert.are.equal(1, shots[1].shot)
      assert.are.equal('2026-02-04 08:47:14', shots[1].timestamp)
    end)
  end)

  describe('repo_matches_filter', function()
    it('matches full repo name when filter includes owner', function()
      assert.is_true(data.repo_matches_filter('divramod/shooter.nvim', 'divramod/shooter.nvim'))
    end)

    it('matches short repo name when filter omits owner', function()
      assert.is_true(data.repo_matches_filter('divramod/shooter.nvim', 'shooter.nvim'))
    end)

    it('does not match similar repo names', function()
      assert.is_false(data.repo_matches_filter('local/shooter.nvim', 'shooter'))
    end)
  end)

  describe('get_git_remote_info', function()
    it('parses repos with dots when using repo root path', function()
      if vim.fn.executable('git') == 0 then return end
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')
      vim.fn.system({ 'git', '-C', tmp, 'init' })
      vim.fn.system({ 'git', '-C', tmp, 'remote', 'add', 'origin', 'git@github.com:divramod/shooter.nvim.git' })

      local user, repo = data.get_git_remote_info(tmp)
      vim.fn.delete(tmp, 'rf')

      assert.are.equal('divramod', user)
      assert.are.equal('shooter.nvim', repo)
    end)
  end)
end)
