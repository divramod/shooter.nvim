-- Characterization tests for shooter.syntax.
-- Pins observable behavior of the extmark-based highlighting engine prior
-- to the T005 split into syntax/{init,highlights,detect,apply,info,autocmds,overrides}.
-- After T005 these helpers move to syntax/detect.lua + syntax/apply.lua and
-- the public surface re-exports them from init.lua.

local syntax = require('shooter.syntax')

local function fresh_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  if lines then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end
  return bufnr
end

local function get_marks(bufnr)
  local ns = vim.api.nvim_get_namespaces()['shooter_syntax']
  if not ns then return {} end
  return vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
end

describe('shooter.syntax', function()
  describe('is_fence_delimiter', function()
    it('detects bare ```', function()
      assert.is_true(syntax.is_fence_delimiter('```'))
    end)

    it('detects ``` with language tag', function()
      assert.is_true(syntax.is_fence_delimiter('```lua'))
      assert.is_true(syntax.is_fence_delimiter('```python'))
    end)

    it('detects indented fence', function()
      assert.is_true(syntax.is_fence_delimiter('  ```'))
      assert.is_true(syntax.is_fence_delimiter('\t```'))
    end)

    it('rejects plain text', function()
      assert.is_false(syntax.is_fence_delimiter('hello world'))
      assert.is_false(syntax.is_fence_delimiter('## shot 1'))
      assert.is_false(syntax.is_fence_delimiter(''))
    end)

    it('rejects inline-code (two ``` on same line are not a fence)', function()
      assert.is_false(syntax.is_fence_delimiter('use ``` here ```'))
    end)
  end)

  describe('build_code_block_map', function()
    it('returns empty map for no fences', function()
      local map = syntax.build_code_block_map({ 'a', 'b', 'c' })
      assert.is_nil(map[1])
      assert.is_nil(map[2])
      assert.is_nil(map[3])
    end)

    it('marks lines between fences as in_code (including the open fence)', function()
      local lines = { 'a', '```', 'in', 'code', '```', 'b' }
      local map = syntax.build_code_block_map(lines)
      assert.is_nil(map[1])    -- before fence
      assert.is_true(map[2])   -- opening fence — in_block flips before mark
      assert.is_true(map[3])   -- inside
      assert.is_true(map[4])   -- inside
      assert.is_nil(map[5])    -- closing fence — in_block flips back; not marked
      assert.is_nil(map[6])    -- after fence
    end)

    it('handles unterminated fence (no closing)', function()
      local lines = { 'a', '```lua', 'inside', 'still inside' }
      local map = syntax.build_code_block_map(lines)
      assert.is_nil(map[1])
      assert.is_true(map[2])
      assert.is_true(map[3])
      assert.is_true(map[4])
    end)

    it('handles multiple code blocks', function()
      local lines = { 'a', '```', 'x', '```', 'b', '```', 'y', '```', 'c' }
      local map = syntax.build_code_block_map(lines)
      assert.is_true(map[2]); assert.is_true(map[3])
      assert.is_nil(map[5])
      assert.is_true(map[6]); assert.is_true(map[7])
      assert.is_nil(map[9])
    end)
  end)

  describe('split_executed_header', function()
    it('returns nil for non-executed headers', function()
      local n = syntax.split_executed_header('## shot 1 hello')
      assert.is_nil(n)
    end)

    it('returns nil for plain text', function()
      assert.is_nil(syntax.split_executed_header('just a sentence'))
    end)

    it('parses ## x shot N (timestamp) — no title', function()
      local number_end, ts, te = syntax.split_executed_header('## x shot 5 (2026-04-26 10:00:00)')
      assert.is_number(number_end)
      assert.is_nil(ts)
      assert.is_nil(te)
    end)

    it('parses ## x shot N <title> (timestamp)', function()
      local line = '## x shot 5 hello world (2026-04-26 10:00:00)'
      local number_end, title_start, title_end = syntax.split_executed_header(line)
      assert.is_number(number_end)
      assert.is_number(title_start)
      assert.is_number(title_end)
      assert.is_true(title_start > number_end)
      assert.is_true(title_end > title_start)
      -- title slice should include "hello world"
      assert.is_truthy(line:sub(title_start, title_end - 1):find('hello'))
    end)

    it('handles ## x shot ? (unparsed shot)', function()
      local n = syntax.split_executed_header('## x shot ? (2026-04-26 10:00:00)')
      assert.is_number(n)
    end)

    it('handles header without timestamp (treats rest as title)', function()
      local line = '## x shot 5 leftover text'
      local number_end, title_start, title_end = syntax.split_executed_header(line)
      assert.is_number(number_end)
      assert.is_number(title_start)
      assert.are.equal(#line, title_end)
    end)
  end)

  describe('is_prompts_file', function()
    it('matches docs/shotfiles/<file>.md', function()
      assert.is_true(syntax.is_prompts_file('/foo/docs/shotfiles/file.md'))
    end)

    it('matches docs/shotfiles subdir', function()
      assert.is_true(syntax.is_prompts_file('/foo/docs/shotfiles/sub/file.md'))
      assert.is_true(syntax.is_prompts_file('/foo/docs/shotfiles/a/b/c/x.md'))
    end)

    it('rejects oil:// scheme', function()
      assert.is_false(syntax.is_prompts_file('oil:///foo/docs/shotfiles/file.md'))
    end)

    it('rejects non-md files', function()
      assert.is_false(syntax.is_prompts_file('/foo/docs/shotfiles/file.txt'))
      assert.is_false(syntax.is_prompts_file('/foo/docs/shotfiles/README'))
    end)

    it('rejects unrelated paths', function()
      assert.is_false(syntax.is_prompts_file('/foo/bar/file.md'))
      assert.is_false(syntax.is_prompts_file('/foo/docs/plans/idea.md'))
    end)
  end)

  describe('apply_syntax (extmark engine)', function()
    it('places extmark on open shot header', function()
      local bufnr = fresh_buf({
        '## shot 1 hello',
        'body line',
      })
      syntax.apply_syntax(bufnr)
      local marks = get_marks(bufnr)
      assert.is_true(#marks > 0)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('places extmarks for executed shot header (latest)', function()
      local bufnr = fresh_buf({
        '## x shot 1 (2026-04-26 10:00:00)',
        'body',
      })
      syntax.apply_syntax(bufnr)
      local marks = get_marks(bufnr)
      assert.is_true(#marks >= 1)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('does not highlight shot inside code block', function()
      local bufnr = fresh_buf({
        '```',
        '## shot 1 inside code',
        '```',
      })
      syntax.apply_syntax(bufnr)
      local marks = get_marks(bufnr)
      -- The code block lines are skipped — but they may still produce
      -- markdown-link matches if any. The shot header itself must not match.
      for _, m in ipairs(marks) do
        local row = m[2]
        local hl = m[4].hl_group or ''
        if row == 1 then
          assert.is_falsy(hl:match('OpenShot'))
        end
      end
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('clears + reapplies on second call (idempotent)', function()
      local bufnr = fresh_buf({ '## shot 1 hello' })
      syntax.apply_syntax(bufnr)
      local first = #get_marks(bufnr)
      syntax.apply_syntax(bufnr)
      local second = #get_marks(bufnr)
      assert.are.equal(first, second)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('handles empty buffer', function()
      local bufnr = fresh_buf({})
      assert.has_no.errors(function() syntax.apply_syntax(bufnr) end)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('only highlights latest executed shot among multiple', function()
      local bufnr = fresh_buf({
        '## x shot 1 (2026-04-26 09:00:00)',
        'body 1',
        '## x shot 2 (2026-04-26 10:00:00)',
        'body 2',
      })
      syntax.apply_syntax(bufnr)
      local marks = get_marks(bufnr)
      -- Latest should be on line 2 (0-indexed). Tally hl groups touching that row.
      local latest_marks = 0
      for _, m in ipairs(marks) do
        local row = m[2]
        local hl = m[4].hl_group or ''
        if row == 2 and hl:match('DoneShot') then
          latest_marks = latest_marks + 1
        end
      end
      assert.is_true(latest_marks > 0)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe('toggle_day_marker', function()
    it('runs without error on a non-shotfile buffer', function()
      local bufnr = vim.api.nvim_create_buf(true, false)
      local prev = vim.api.nvim_get_current_buf()
      vim.api.nvim_set_current_buf(bufnr)
      assert.has_no.errors(function() syntax.toggle_day_marker() end)
      vim.api.nvim_set_current_buf(prev)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('toggles state twice without error', function()
      assert.has_no.errors(function()
        syntax.toggle_day_marker()
        syntax.toggle_day_marker()
      end)
    end)
  end)

  describe('setup', function()
    it('runs without error and registers autocmd group', function()
      assert.has_no.errors(function() syntax.setup() end)
      local groups = vim.api.nvim_get_autocmds({ group = 'HalShooterSyntax' })
      assert.is_true(#groups > 0)
    end)
  end)

  describe('reapply_all', function()
    it('runs without error', function()
      assert.has_no.errors(function() syntax.reapply_all() end)
    end)

    it('iterates loaded buffers without crashing on non-shotfile bufs', function()
      local bufnr = fresh_buf({ 'random content' })
      assert.has_no.errors(function() syntax.reapply_all() end)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe('define_highlights', function()
    it('runs without error and creates expected highlight groups', function()
      assert.has_no.errors(function() syntax.define_highlights() end)
      -- Spot-check a couple of groups
      local hl = vim.api.nvim_get_hl(0, { name = 'HalShooterOpenShot' })
      assert.is_table(hl)
      hl = vim.api.nvim_get_hl(0, { name = 'HalShooterMdLink' })
      assert.is_table(hl)
    end)
  end)

  describe('show_shotfile_info', function()
    it('runs without error on a valid buffer (one-shot per buffer)', function()
      local bufnr = fresh_buf({ '## shot 1', 'body' })
      assert.has_no.errors(function() syntax.show_shotfile_info(bufnr) end)
      -- Second call should short-circuit via notified_bufs map
      assert.has_no.errors(function() syntax.show_shotfile_info(bufnr) end)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('drains its scheduled callback (covers stats-gathering branch)', function()
      local bufnr = fresh_buf({ '## shot 1 hi', 'body', '## x shot 2 (2026-04-26 10:00:00)', 'b' })
      syntax.show_shotfile_info(bufnr)
      -- Drain the vim.schedule queue so the inner closure runs.
      vim.wait(50, function() return false end, 5)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe('apply_syntax — additional branches', function()
    it('highlights open shot WITH title (split into number + title)', function()
      local bufnr = fresh_buf({ '## shot 5 my title' })
      syntax.apply_syntax(bufnr)
      local marks = get_marks(bufnr)
      local has_number, has_title = false, false
      for _, m in ipairs(marks) do
        local hl = m[4].hl_group or ''
        if hl == 'HalShooterOpenShot' then has_number = true end
        if hl == 'HalShooterOpenShotTitle' then has_title = true end
      end
      assert.is_true(has_number)
      assert.is_true(has_title)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('highlights open shot WITHOUT title (whole-line single mark)', function()
      local bufnr = fresh_buf({ '## shot 5' })
      syntax.apply_syntax(bufnr)
      local marks = get_marks(bufnr)
      local has_open = false
      for _, m in ipairs(marks) do
        local hl = m[4].hl_group or ''
        if hl == 'HalShooterOpenShot' then has_open = true end
      end
      assert.is_true(has_open)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('highlights executed shot WITH title (prefix + title + postfix)', function()
      local bufnr = fresh_buf({ '## x shot 7 a nice title (2026-04-26 10:00:00) @ref' })
      syntax.apply_syntax(bufnr)
      local marks = get_marks(bufnr)
      local prefix, title, postfix = false, false, false
      for _, m in ipairs(marks) do
        local hl = m[4].hl_group or ''
        if hl == 'HalShooterDoneShotPrefix' then prefix = true end
        if hl == 'HalShooterDoneShotTitle' then title = true end
        if hl == 'HalShooterDoneShotPostfix' then postfix = true end
      end
      assert.is_true(prefix)
      assert.is_true(title)
      assert.is_true(postfix)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('highlights markdown links on non-shot lines', function()
      local bufnr = fresh_buf({ 'see [docs](https://example.com) here' })
      syntax.apply_syntax(bufnr)
      local marks = get_marks(bufnr)
      local has_link = false
      for _, m in ipairs(marks) do
        if (m[4].hl_group or '') == 'HalShooterMdLink' then has_link = true end
      end
      assert.is_true(has_link)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe('toggle_day_marker on a shotfile buffer', function()
    it('triggers reapply when the current buffer is a shotfile', function()
      -- Create a buffer with a path matching docs/shotfiles/<file>.md
      local tmp = vim.fn.tempname() .. '/docs/shotfiles/toggle.md'
      vim.fn.mkdir(vim.fn.fnamemodify(tmp, ':h'), 'p')
      vim.fn.writefile({ '## shot 1 hi' }, tmp)
      vim.cmd('edit ' .. vim.fn.fnameescape(tmp))
      local bufnr = vim.api.nvim_get_current_buf()
      assert.has_no.errors(function() syntax.toggle_day_marker() end)
      assert.has_no.errors(function() syntax.toggle_day_marker() end)
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      vim.fn.delete(vim.fn.fnamemodify(tmp, ':h:h:h'), 'rf')
    end)
  end)

  describe('autocmd dispatch (BufEnter / TextChanged / ColorScheme)', function()
    it('exercises the BufEnter callback on a shotfile path', function()
      syntax.setup()
      local tmp = vim.fn.tempname() .. '/docs/shotfiles/auto.md'
      vim.fn.mkdir(vim.fn.fnamemodify(tmp, ':h'), 'p')
      vim.fn.writefile({ '## shot 1 hi' }, tmp)
      vim.cmd('edit ' .. vim.fn.fnameescape(tmp))
      local bufnr = vim.api.nvim_get_current_buf()
      vim.bo[bufnr].filetype = 'markdown'
      -- Trigger autocmds explicitly (edit may not fire all of them in headless)
      vim.api.nvim_exec_autocmds('BufEnter', { buffer = bufnr })
      vim.api.nvim_exec_autocmds('TextChanged', { buffer = bufnr })
      vim.api.nvim_exec_autocmds('ColorScheme', {})
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      vim.fn.delete(vim.fn.fnamemodify(tmp, ':h:h:h'), 'rf')
    end)
  end)
end)
