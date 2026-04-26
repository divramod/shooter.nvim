-- Characterization tests for shooter.plans.metaplan parse seam.
-- Locks parse-side behavior before the Phase 001 T004 split into
-- metaplan/parse.lua. The exhaustive parse-via-fix tests live in
-- metaplan_spec.lua; this file pins the parse() shape contract.

local metaplan = require('shooter.plans.metaplan')

describe('shooter.plans.metaplan parse seam', function()
  describe('parse', function()
    it('returns a table with sections', function()
      local p = metaplan.parse([[# metaplan myrepo

## in progress
- 0001-foo

## next plans
- 0002-bar
]])
      assert.is_table(p)
      assert.is_table(p.sections)
    end)

    it('handles empty input', function()
      local p = metaplan.parse('')
      assert.is_table(p)
      assert.is_table(p.sections)
    end)

    it('handles content with only a title', function()
      local p = metaplan.parse('# metaplan myrepo\n')
      assert.is_table(p)
      assert.is_table(p.sections)
    end)
  end)

  describe('slugify', function()
    it('lowercases and hyphenates', function()
      assert.equals('hello-world', metaplan.slugify('Hello World'))
    end)

    it('strips parentheses content', function()
      -- pre-paren only, parens are handled separately in extract_extras
      local s = metaplan.slugify('foo bar')
      assert.equals('foo-bar', s)
    end)

    it('preserves clean slugs', function()
      assert.equals('foo-bar-baz', metaplan.slugify('foo-bar-baz'))
    end)
  end)

  describe('extract_plan_name', function()
    it('extracts NNNN-slug from a list-entry line', function()
      local n = metaplan.extract_plan_name('- 0042-some-plan')
      assert.equals('0042-some-plan', n)
    end)

    it('returns nil for a non-plan line', function()
      assert.is_nil(metaplan.extract_plan_name('## next plans'))
      assert.is_nil(metaplan.extract_plan_name(''))
    end)
  end)

  describe('extract_extras', function()
    it('returns description+notes table for an entry', function()
      local p = metaplan.parse([[# metaplan myrepo

## next plans
- 0002-bar (some description)
  - sub-note
]])
      -- find the bar entry
      local entry
      for _, sec in ipairs(p.sections or {}) do
        for _, e in ipairs(sec.entries or {}) do
          if e.name and e.name:match('bar') then entry = e end
        end
      end
      if entry then
        local extras = metaplan.extract_extras(entry)
        assert.is_table(extras)
      end
    end)
  end)
end)
