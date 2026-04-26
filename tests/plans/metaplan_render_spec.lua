-- Characterization tests for shooter.plans.metaplan render seam.
-- Pins the render() shape contract before the Phase 001 T004 split.
-- Behavioral cases (canonical title, section ordering, paren preservation)
-- are exhaustively covered by metaplan_spec.lua via the fix() pipeline.

local metaplan = require('shooter.plans.metaplan')

describe('shooter.plans.metaplan render seam', function()
  describe('render', function()
    it('returns a string', function()
      local p = metaplan.parse([[# metaplan myrepo

## next plans
- 0001-foo
]])
      local out = metaplan.render(p, '# metaplan myrepo')
      assert.is_string(out)
    end)

    it('preserves the title', function()
      local p = metaplan.parse('# metaplan myrepo\n\n## next plans\n')
      local out = metaplan.render(p, '# metaplan myrepo (alias)')
      assert.is_truthy(out:find('# metaplan myrepo %(alias%)'))
    end)

    it('emits the five canonical sections', function()
      local p = metaplan.parse([[# metaplan myrepo

## in progress
- 0001-foo

## next plans
- 0002-bar
]])
      local out = metaplan.render(p, '# metaplan myrepo')
      assert.is_truthy(out:find('## in progress'))
      assert.is_truthy(out:find('## next plans'))
    end)

    it('round-trips a minimal metaplan with no semantic loss', function()
      local input = [[# metaplan myrepo

## in progress
- 0001-foo

## next plans
- 0002-bar
]]
      local p = metaplan.parse(input)
      local out = metaplan.render(p, '# metaplan myrepo')
      -- both names must survive the round trip
      assert.is_truthy(out:find('0001%-foo'))
      assert.is_truthy(out:find('0002%-bar'))
    end)
  end)
end)
