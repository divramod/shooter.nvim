-- Characterization tests for shooter.plans.metaplan rename seam.
-- This is the **security-sensitive** seam — Phase 001 T005 hardens
-- path-traversal defenses and re-runs these tests as the regression
-- guard. Behavioral coverage of the success path lives in
-- metaplan_spec.lua via the fix() pipeline.

local metaplan = require('shooter.plans.metaplan')

describe('shooter.plans.metaplan rename seam', function()
  it('exports rename_plan', function()
    assert.is_function(metaplan.rename_plan)
  end)

  it('exports rewrite_metaplan_line', function()
    assert.is_function(metaplan.rewrite_metaplan_line)
  end)

  it('exports remove_metaplan_entry', function()
    assert.is_function(metaplan.remove_metaplan_entry)
  end)

  it('exports delete_plan', function()
    assert.is_function(metaplan.delete_plan)
  end)

  it('exports delete_plan_preflight', function()
    assert.is_function(metaplan.delete_plan_preflight)
  end)

  describe('rename_plan input validation', function()
    -- rename_plan returns (false, reason) on bad input — never throws.
    -- These pin the current contract; Phase 001 T005 will tighten the
    -- regex / canonicalization for path-traversal hardening.

    it('rejects an empty new name', function()
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')
      local ok = metaplan.rename_plan(tmp, '0001-foo', '')
      assert.is_false(ok)
      vim.fn.delete(tmp, 'rf')
    end)

    it('rejects a new name that does not match NNNN-slug', function()
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')
      local ok = metaplan.rename_plan(tmp, '0001-foo', '../bad')
      assert.is_false(ok)
      ok = metaplan.rename_plan(tmp, '0001-foo', 'no-number-prefix')
      assert.is_false(ok)
      vim.fn.delete(tmp, 'rf')
    end)

    it('rejects when old_name == new_name', function()
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')
      local ok = metaplan.rename_plan(tmp, '0001-foo', '0001-foo')
      assert.is_false(ok)
      vim.fn.delete(tmp, 'rf')
    end)
  end)

  describe('delete_plan_preflight', function()
    it('returns true when only idea.md is present', function()
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp .. '/docs/plans/0001-foo', 'p')
      vim.fn.writefile({ 'idea' }, tmp .. '/docs/plans/0001-foo/idea.md')
      local ok = metaplan.delete_plan_preflight(tmp, '0001-foo', false)
      assert.is_true(ok)
      vim.fn.delete(tmp, 'rf')
    end)

    it('returns false + reason when extra files are present', function()
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp .. '/docs/plans/0001-foo', 'p')
      vim.fn.writefile({ 'idea' }, tmp .. '/docs/plans/0001-foo/idea.md')
      vim.fn.writefile({ 'spec' }, tmp .. '/docs/plans/0001-foo/spec.md')
      local ok, reason = metaplan.delete_plan_preflight(tmp, '0001-foo', false)
      assert.is_false(ok)
      assert.is_string(reason)
      vim.fn.delete(tmp, 'rf')
    end)

    it('returns true when force=true regardless of content', function()
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp .. '/docs/plans/0001-foo', 'p')
      vim.fn.writefile({ 'spec' }, tmp .. '/docs/plans/0001-foo/spec.md')
      local ok = metaplan.delete_plan_preflight(tmp, '0001-foo', true)
      assert.is_true(ok)
      vim.fn.delete(tmp, 'rf')
    end)
  end)
end)
