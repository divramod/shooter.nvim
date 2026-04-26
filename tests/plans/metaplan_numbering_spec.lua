-- Characterization tests for shooter.plans.metaplan numbering seam.
-- Locks the public surface for collect_used_numbers / next_free_plan_number /
-- next_plans_number_at ahead of the Phase 001 T004 split. Exhaustive
-- behavioral coverage is in metaplan_spec.lua via the fix() pipeline.

local metaplan = require('shooter.plans.metaplan')

describe('shooter.plans.metaplan numbering seam', function()
  it('exports collect_used_numbers', function()
    assert.is_function(metaplan.collect_used_numbers)
  end)

  it('exports next_plans_number_at', function()
    assert.is_function(metaplan.next_plans_number_at)
  end)

  it('exports next_free_plan_number', function()
    assert.is_function(metaplan.next_free_plan_number)
  end)

  describe('next_plans_number_at', function()
    -- Semantics: returns the k-th smallest UNUSED number (1-indexed).
    -- Used by gap-fill to assign N plans the same way render() will.

    it('returns the 1st unused number when k=1', function()
      -- used = { 1, 2, 3, 5 }; 1st unused is 4
      local used = { [1] = true, [2] = true, [3] = true, [5] = true }
      assert.equals(4, metaplan.next_plans_number_at(used, 1))
    end)

    it('returns the k-th unused (not smallest ≥ k)', function()
      -- used = { 1, 2 }; unused are 3, 4, 5, …; 3rd unused is 5
      local used = { [1] = true, [2] = true }
      assert.equals(5, metaplan.next_plans_number_at(used, 3))
    end)

    it('returns k when nothing is used', function()
      assert.equals(1, metaplan.next_plans_number_at({}, 1))
      assert.equals(3, metaplan.next_plans_number_at({}, 3))
    end)
  end)

  describe('list_worktree_roots', function()
    it('returns a table even outside a git repo', function()
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')
      local roots = metaplan.list_worktree_roots(tmp)
      assert.is_table(roots)
      vim.fn.delete(tmp, 'rf')
    end)
  end)
end)
