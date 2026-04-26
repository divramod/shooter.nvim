-- Tests for shooter.plans.picker
local plan_picker = require('shooter.plans.picker')
local utils = require('shooter.utils')

describe('shooter.plans.picker', function()
  local repo = '/tmp/shooter_plan_picker_test'

  local function mkfile(path, content)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
    utils.write_file(path, content or '')
  end

  before_each(function()
    os.execute('rm -rf ' .. repo)
    os.execute('mkdir -p ' .. repo)
  end)

  after_each(function()
    os.execute('rm -rf ' .. repo)
  end)

  describe('find', function()
    it('returns empty list when docs/plans is missing', function()
      assert.same({}, plan_picker.find(repo, 'plan'))
    end)

    it('returns empty list when git_root is nil or empty', function()
      assert.same({}, plan_picker.find(nil, 'plan'))
      assert.same({}, plan_picker.find('', 'plan'))
    end)

    it('finds plan.md files at any nesting depth', function()
      mkfile(repo .. '/docs/plans/0001-foo/plan.md')
      mkfile(repo .. '/docs/plans/0002-bar/phase-a/plan.md')
      mkfile(repo .. '/docs/plans/0003-deep/a/b/c/plan.md')
      -- Not matching basename
      mkfile(repo .. '/docs/plans/0001-foo/spec.md')
      -- Different extension
      mkfile(repo .. '/docs/plans/0001-foo/plan.txt')

      local paths = plan_picker.find(repo, 'plan')
      assert.equals(3, #paths)
      table.sort(paths)
      assert.equals(repo .. '/docs/plans/0001-foo/plan.md', paths[1])
      assert.equals(repo .. '/docs/plans/0002-bar/phase-a/plan.md', paths[2])
      assert.equals(repo .. '/docs/plans/0003-deep/a/b/c/plan.md', paths[3])
    end)

    it('filters by the given basename', function()
      mkfile(repo .. '/docs/plans/0001-foo/plan.md')
      mkfile(repo .. '/docs/plans/0001-foo/context.md')
      mkfile(repo .. '/docs/plans/0001-foo/spec.md')
      mkfile(repo .. '/docs/plans/0002-bar/context.md')

      local plans = plan_picker.find(repo, 'plan')
      local ctxs = plan_picker.find(repo, 'context')
      local specs = plan_picker.find(repo, 'spec')
      assert.equals(1, #plans)
      assert.equals(2, #ctxs)
      assert.equals(1, #specs)
    end)

    it('returns sorted results', function()
      mkfile(repo .. '/docs/plans/zzz/plan.md')
      mkfile(repo .. '/docs/plans/aaa/plan.md')
      mkfile(repo .. '/docs/plans/mmm/plan.md')
      local paths = plan_picker.find(repo, 'plan')
      assert.is_true(paths[1] < paths[2])
      assert.is_true(paths[2] < paths[3])
    end)
  end)

  describe('find_shotfiles', function()
    local shot_dir = repo .. '/docs/shotfiles/docs/plans'

    it('returns empty list when the shotfile dir is missing', function()
      assert.same({}, plan_picker.find_shotfiles(repo))
    end)

    it('returns empty list when git_root is nil or empty', function()
      assert.same({}, plan_picker.find_shotfiles(nil))
      assert.same({}, plan_picker.find_shotfiles(''))
    end)

    it('lists only direct-child .md files, sorted by name', function()
      mkfile(shot_dir .. '/0003-zeta.md')
      mkfile(shot_dir .. '/0001-alpha.md')
      mkfile(shot_dir .. '/0002-beta.md')
      -- Non-md should be ignored
      mkfile(shot_dir .. '/notes.txt')
      -- Nested directory should be ignored (flat listing)
      mkfile(shot_dir .. '/sub/0099-nested.md')

      local paths = plan_picker.find_shotfiles(repo)
      assert.equals(3, #paths)
      assert.equals(shot_dir .. '/0001-alpha.md', paths[1])
      assert.equals(shot_dir .. '/0002-beta.md', paths[2])
      assert.equals(shot_dir .. '/0003-zeta.md', paths[3])
    end)
  end)

  describe('sort_by_age_with_tiebreak', function()
    local shot_dir = repo .. '/docs/shotfiles/docs/plans'

    it('sorts newest-first by mtime', function()
      local paths = {
        shot_dir .. '/old.md',
        shot_dir .. '/middle.md',
        shot_dir .. '/new.md',
      }
      for _, p in ipairs(paths) do mkfile(p) end
      local now = os.time()
      vim.loop.fs_utime(paths[1], now - 7200, now - 7200)  -- 2h old
      vim.loop.fs_utime(paths[2], now - 3600, now - 3600)  -- 1h old
      vim.loop.fs_utime(paths[3], now,        now)         -- newest

      local entries = {}
      for _, p in ipairs(paths) do
        local rel = p:sub(#shot_dir + 2)
        table.insert(entries, { path = p, display = rel, ordinal = rel })
      end
      plan_picker.sort_by_age_with_tiebreak(entries)
      assert.truthy(entries[1].display:find('^new%.md '))
      assert.truthy(entries[2].display:find('^middle%.md '))
      assert.truthy(entries[3].display:find('^old%.md '))
    end)

    it('breaks mtime ties alphabetically by filename', function()
      local paths = {
        shot_dir .. '/zebra.md',
        shot_dir .. '/apple.md',
        shot_dir .. '/mango.md',
      }
      for _, p in ipairs(paths) do mkfile(p) end
      local same = os.time() - 30  -- all same mtime
      for _, p in ipairs(paths) do
        vim.loop.fs_utime(p, same, same)
      end

      local entries = {}
      for _, p in ipairs(paths) do
        local rel = p:sub(#shot_dir + 2)
        table.insert(entries, { path = p, display = rel, ordinal = rel })
      end
      plan_picker.sort_by_age_with_tiebreak(entries)
      -- Same age → alphabetical
      assert.truthy(entries[1].display:find('^apple%.md '))
      assert.truthy(entries[2].display:find('^mango%.md '))
      assert.truthy(entries[3].display:find('^zebra%.md '))
    end)

    it('appends a "(<age>)" suffix to each display string', function()
      local p = shot_dir .. '/foo.md'
      mkfile(p)
      vim.loop.fs_utime(p, os.time() - 300, os.time() - 300)  -- 5m
      local entries = { { path = p, display = 'foo.md', ordinal = 'foo.md' } }
      plan_picker.sort_by_age_with_tiebreak(entries)
      -- Suffix is "(<some age string>)" — exact format is recency.format_relative's
      assert.truthy(entries[1].display:find('^foo%.md %(.+%)$'))
      -- Ordinal is updated to mirror display so telescope filters on it.
      assert.equals(entries[1].display, entries[1].ordinal)
    end)
  end)

  describe('plan_categories', function()
    local mp_path = repo .. '/docs/plans/masterplan.md'

    it('maps each masterplan plan to its 2-char section code', function()
      mkfile(mp_path, table.concat({
        '# masterplan test',
        '',
        '## in progress',
        '- 0001-active',
        '',
        '## planned',
        '- 0002-coming-soon',
        '',
        '## next plans',
        '- 0003-tentative',
        '',
        '## backlog',
        '- 0004-on-hold',
        '',
        '## done',
        '- 0005-finished (2026-04-01 10:00:00)',
        '',
      }, '\n'))
      local cats = plan_picker.plan_categories(repo)
      assert.equals('ip', cats['0001-active'])
      assert.equals('pl', cats['0002-coming-soon'])
      assert.equals('np', cats['0003-tentative'])
      assert.equals('bl', cats['0004-on-hold'])
      assert.equals('do', cats['0005-finished'])
    end)

    it('returns empty table when masterplan is missing', function()
      assert.same({}, plan_picker.plan_categories(repo))
    end)

    it('returns empty table for nil or empty git_root', function()
      assert.same({}, plan_picker.plan_categories(nil))
      assert.same({}, plan_picker.plan_categories(''))
    end)

    it('skips lines with no plan reference', function()
      mkfile(mp_path, table.concat({
        '## in progress',
        '- 0001-real',
        '- a plain note with no plan',
        '  - indented child not a top entry',
        '',
      }, '\n'))
      local cats = plan_picker.plan_categories(repo)
      assert.equals('ip', cats['0001-real'])
      -- No spurious entries
      local count = 0
      for _ in pairs(cats) do count = count + 1 end
      assert.equals(1, count)
    end)
  end)
end)
