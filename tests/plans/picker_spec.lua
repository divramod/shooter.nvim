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
end)
