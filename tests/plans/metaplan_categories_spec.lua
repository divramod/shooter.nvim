-- Characterization tests for shooter.plans.metaplan classification seam.
-- Pins the public surface for classify_plan / plan_files_in_worktree
-- ahead of the Phase 001 T004 split. Behavior is exhaustively tested
-- via the fix() pipeline in metaplan_spec.lua.

local metaplan = require('shooter.plans.metaplan')

describe('shooter.plans.metaplan classification seam', function()
  it('exports classify_plan', function()
    assert.is_function(metaplan.classify_plan)
  end)

  it('exports plan_files_in_worktree', function()
    assert.is_function(metaplan.plan_files_in_worktree)
  end)

  it('exports list_worktree_roots', function()
    assert.is_function(metaplan.list_worktree_roots)
  end)

  describe('plan_files_in_worktree', function()
    it('returns a table even when no docs/plans exists', function()
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')
      local files = metaplan.plan_files_in_worktree(tmp, '0001-nonexistent')
      assert.is_table(files)
      vim.fn.delete(tmp, 'rf')
    end)

    it('detects spec.md / masterplan.md / hal.yml when present', function()
      local tmp = vim.fn.tempname()
      local plan_dir = tmp .. '/docs/plans/0042-foo'
      vim.fn.mkdir(plan_dir, 'p')
      vim.fn.writefile({ 'spec' }, plan_dir .. '/spec.md')
      vim.fn.writefile({ 'master' }, plan_dir .. '/masterplan.md')
      vim.fn.writefile({ 'started_at: 2026-01-01' }, plan_dir .. '/hal.yml')

      local files = metaplan.plan_files_in_worktree(tmp, '0042-foo')
      assert.is_table(files)

      vim.fn.delete(tmp, 'rf')
    end)
  end)
end)
