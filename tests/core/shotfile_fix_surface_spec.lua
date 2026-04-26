-- Public-surface contract for shooter.core.shotfile_fix.
-- Locks the 8-fn surface; behavioral coverage in shotfile_fix_spec.lua.
-- File is review-only per Phase 002 T001 (312 LOC, under 350 cap).

local sf = require('shooter.core.shotfile_fix')

describe('shooter.core.shotfile_fix public surface', function()
  local expected = {
    'header_has_no_title',
    'normalize_blank_lines',
    'strip_trailing_blanks',
    'strip_empty_shots',
    'fix_buffer',
    'build_commit_message',
    'commit',
    'fix_file',
    'run_all',
    'run',
  }
  for _, fn in ipairs(expected) do
    it('exports M.' .. fn, function()
      assert.is_function(sf[fn])
    end)
  end

  describe('header_has_no_title', function()
    it('returns true for "## shot 5"', function()
      assert.is_true(sf.header_has_no_title('## shot 5'))
    end)

    it('returns true for "## x shot 5"', function()
      assert.is_true(sf.header_has_no_title('## x shot 5'))
    end)

    it('returns false when a title follows the number', function()
      assert.is_false(sf.header_has_no_title('## shot 5 my title'))
    end)

    it('returns false for non-shot lines', function()
      assert.is_false(sf.header_has_no_title('# foo'))
      assert.is_false(sf.header_has_no_title(''))
    end)
  end)

  describe('strip_trailing_blanks', function()
    it('removes trailing blank lines', function()
      local out = sf.strip_trailing_blanks({ 'a', 'b', '', '' })
      assert.equals(2, #out)
      assert.equals('a', out[1])
      assert.equals('b', out[2])
    end)

    it('is a no-op when no trailing blanks', function()
      local out = sf.strip_trailing_blanks({ 'a', 'b' })
      assert.equals(2, #out)
    end)

    it('handles all-blank input', function()
      local out = sf.strip_trailing_blanks({ '', '', '' })
      assert.equals(0, #out)
    end)
  end)

  describe('build_commit_message', function()
    it('returns a string referencing the file path (full stats shape)', function()
      local msg = sf.build_commit_message('docs/shotfiles/foo.md',
        { title_fixed = true, removed = 0 })
      assert.is_string(msg)
      assert.is_truthy(msg:find('foo'))
    end)

    it('mentions empty-shot removal when removed > 0', function()
      local msg = sf.build_commit_message('docs/shotfiles/bar.md',
        { title_fixed = false, removed = 2 })
      assert.is_truthy(msg:find('empty shot'))
    end)
  end)
end)
