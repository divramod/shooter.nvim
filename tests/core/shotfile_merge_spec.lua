local merge = require('shooter.core.shotfile_merge')

describe('shooter.core.shotfile_merge', function()
  describe('build_merged', function()
    it('inserts source shots at top of target shots, preserves target H1', function()
      local source = {
        '# src',
        '',
        '## shot 1 alpha',
        'a body',
      }
      local target = {
        '# tgt',
        '',
        '## shot 1 beta',
        'b body',
      }
      local merged = merge.build_merged(source, target)
      local joined = table.concat(merged, '\n')
      -- Target H1 stays first
      assert.equals('# tgt', merged[1])
      -- Source shot appears before target shot
      local src_idx = joined:find('## shot 1 alpha', 1, true)
      local tgt_idx = joined:find('## shot 1 beta', 1, true)
      assert.truthy(src_idx and tgt_idx and src_idx < tgt_idx)
    end)

    it('drops source prefix (title) from the merge', function()
      local source = { '# src', '', '## shot 1 alpha', 'body' }
      local target = { '# tgt', '', '## shot 1 beta', 'body' }
      local merged = merge.build_merged(source, target)
      -- Only one H1 heading should exist in the output.
      local count = 0
      for _, line in ipairs(merged) do
        if line:match('^#%s') and not line:match('^##') then
          count = count + 1
        end
      end
      assert.equals(1, count)
    end)

    it('handles empty target shots', function()
      local source = { '# src', '', '## shot 1 a', 'body' }
      local target = { '# tgt', '' }
      local merged = merge.build_merged(source, target)
      local joined = table.concat(merged, '\n')
      assert.truthy(joined:find('## shot 1 a', 1, true))
      assert.equals('# tgt', merged[1])
    end)

    it('handles empty source shots', function()
      local source = { '# src', '' }
      local target = { '# tgt', '', '## shot 1 b', 'body' }
      local merged = merge.build_merged(source, target)
      assert.equals('# tgt', merged[1])
      assert.truthy(table.concat(merged, '\n'):find('## shot 1 b', 1, true))
    end)

    it('preserves done shots from source', function()
      local source = { '# s', '', '## x shot 1 a (2026-04-10 10:00:00)', 'body' }
      local target = { '# t', '', '## shot 1 b', 'body' }
      local merged = merge.build_merged(source, target)
      assert.truthy(table.concat(merged, '\n'):find('## x shot 1 a', 1, true))
    end)
  end)

  describe('merge_into', function()
    local tmp = '/tmp/shooter_merge_test'
    local src_path = tmp .. '/src.md'
    local tgt_path = tmp .. '/tgt.md'

    before_each(function()
      os.execute('rm -rf ' .. tmp)
      os.execute('mkdir -p ' .. tmp)
      local f = io.open(src_path, 'w')
      f:write('# src\n\n## shot 1 alpha\nfrom source\n')
      f:close()
      f = io.open(tgt_path, 'w')
      f:write('# tgt\n\n## shot 1 beta\nfrom target\n')
      f:close()
    end)

    after_each(function()
      os.execute('rm -rf ' .. tmp)
    end)

    it('merges source into target, deletes source file', function()
      local ok, msg = merge.merge_into(src_path, tgt_path)
      assert.is_true(ok)
      assert.truthy(msg)
      -- Source file is gone
      assert.equals(0, vim.fn.filereadable(src_path))
      -- Target still exists and contains both shot titles
      assert.equals(1, vim.fn.filereadable(tgt_path))
      local content = io.open(tgt_path, 'r'):read('*a')
      assert.truthy(content:find('alpha', 1, true))
      assert.truthy(content:find('beta', 1, true))
      assert.truthy(content:find('^# tgt'))
    end)

    it('rejects merging a file into itself', function()
      local ok, err = merge.merge_into(src_path, src_path)
      assert.is_false(ok)
      assert.truthy(err)
    end)
  end)
end)
