-- Test suite for shooter.core.shot_actions module
local shot_actions = require('shooter.core.shot_actions')
local files = require('shooter.core.files')

describe('shot_actions module', function()
  local original_echo

  before_each(function()
    -- Mock utils.echo to avoid output during tests
    original_echo = require('shooter.utils').echo
    require('shooter.utils').echo = function() end
  end)

  after_each(function()
    require('shooter.utils').echo = original_echo
  end)

  describe('yank_shot', function()
    it('yanks the shot header along with the body content', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '# feats',
        '',
        '## shot 1 HalShooterShotYank',
        'first line of body',
        'second line of body',
      })
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 3, 0 })

      shot_actions.yank_shot()

      local yanked = vim.fn.getreg('"')
      assert.truthy(yanked:find('## shot 1 HalShooterShotYank', 1, true))
      assert.truthy(yanked:find('first line of body', 1, true))
      assert.truthy(yanked:find('second line of body', 1, true))
      -- Header must come before the body in the yanked text.
      local h = yanked:find('## shot 1', 1, true)
      local b = yanked:find('first line', 1, true)
      assert.is_true(h < b)
    end)

    it('yanks just the header when the shot has no body', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '# feats',
        '',
        '## shot 1 empty',
      })
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 3, 0 })

      shot_actions.yank_shot()

      local yanked = vim.fn.getreg('"')
      assert.truthy(yanked:find('## shot 1 empty', 1, true))
    end)
  end)

  describe('find_insertion_line (via create_new_shot)', function()
    it('creates shot without trailing blank when first shot in empty file', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      -- Just a title, no content
      local lines = {
        '# Test Title',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      shot_actions.create_new_shot()
      vim.cmd('stopinsert')

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Expected structure (no content below, no blank after header):
      -- 1: # Test Title
      -- 2: (empty line - separator before)
      -- 3: ## shot 1
      assert.are.equal('# Test Title', result[1])
      assert.are.equal('', result[2], 'Should have blank line between title and shot')
      assert.is_truthy(result[3]:match('^## shot 1'), 'Shot header on line 3')
      assert.are.equal(3, #result, 'Should have exactly 3 lines (no blank after header)')
    end)

    it('creates shot with trailing blank when inserting before existing shots', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## shot 1',
        'Shot 1 content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      shot_actions.create_new_shot()
      vim.cmd('stopinsert')

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- New shot 2 inserted before shot 1, with trailing blank as separator
      local shot2_line = nil
      for i, line in ipairs(result) do
        if line:match('^## shot 2') then shot2_line = i; break end
      end
      assert.is_not_nil(shot2_line)
      -- Should have one blank line as separator before existing shot
      assert.are.equal('', result[shot2_line + 1], 'Separator before existing shot')
    end)

    it('inserts after title when no shots and no orphan text', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      -- Simulate create_new_shot but check buffer state
      shot_actions.create_new_shot()
      vim.cmd('stopinsert')

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- New shot should be after title with blank line before it
      assert.are.equal('', result[2], 'Blank line before shot')
      assert.is_truthy(result[3]:match('^## shot %d+'))
    end)

    it('inserts before first shot when no orphan text', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## shot 1',
        'Shot 1 content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      shot_actions.create_new_shot()
      vim.cmd('stopinsert')

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- New shot (## shot 2) should be inserted before shot 1
      -- Find positions of both shots
      local shot2_line = nil
      local shot1_line = nil
      for i, line in ipairs(result) do
        if line:match('^## shot 2') then shot2_line = i end
        if line:match('^## shot 1') then shot1_line = i end
      end
      assert.is_not_nil(shot2_line, 'Shot 2 should exist')
      assert.is_not_nil(shot1_line, 'Shot 1 should still exist')
      assert.is_true(shot2_line < shot1_line, 'Shot 2 should be before shot 1')
    end)

    it('inserts after meta area when meta area exists', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        'meta info here',
        '',
        '## shot 1',
        'Shot 1 content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      shot_actions.create_new_shot()
      vim.cmd('stopinsert')

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Find positions of new shot header and meta text
      local new_shot_line = nil
      local meta_line = nil
      for i, line in ipairs(result) do
        if line:match('^## shot 2') then
          new_shot_line = i
        end
        if line == 'meta info here' then
          meta_line = i
        end
      end

      -- New shot should be AFTER meta area (meta stays at top)
      assert.is_not_nil(new_shot_line)
      assert.is_not_nil(meta_line)
      assert.is_true(new_shot_line > meta_line,
        'New shot should be after meta area, got shot=' .. tostring(new_shot_line) .. ' meta=' .. tostring(meta_line))
    end)

    it('handles meta area with no existing shots', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        'some notes here',
        'more notes',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      shot_actions.create_new_shot()
      vim.cmd('stopinsert')

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- New shot should be after the meta notes
      local new_shot_line = nil
      local notes_line = nil
      for i, line in ipairs(result) do
        if line:match('^## shot 1') then
          new_shot_line = i
        end
        if line == 'some notes here' then
          notes_line = i
        end
      end

      assert.is_not_nil(new_shot_line)
      assert.is_not_nil(notes_line)
      assert.is_true(new_shot_line > notes_line,
        'New shot should be after meta notes, got shot=' .. tostring(new_shot_line) .. ' notes=' .. tostring(notes_line))
    end)
  end)

  describe('delete_last_shot', function()
    it('deletes the highest numbered non-executed shot', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## shot 2',
        'Shot 2 content',
        '',
        '## x shot 1',
        'Shot 1 executed',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      shot_actions.delete_last_shot()

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Shot 2 should be deleted, shot 1 should remain
      local has_shot2 = false
      local has_shot1 = false
      for _, line in ipairs(result) do
        if line:match('## shot 2') then has_shot2 = true end
        if line:match('## x shot 1') then has_shot1 = true end
      end
      assert.is_false(has_shot2)
      assert.is_true(has_shot1)
    end)

    it('refuses to delete executed shots', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## x shot 1',
        'Shot 1 executed',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      shot_actions.delete_last_shot()

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Shot 1 should still be there
      local has_shot1 = false
      for _, line in ipairs(result) do
        if line:match('## x shot 1') then has_shot1 = true end
      end
      assert.is_true(has_shot1)
    end)
  end)

  describe('toggle_shot_done', function()
    it('marks open shot as done with timestamp', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## shot 1',
        'Shot 1 content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 3, 0 })  -- Position in shot 1

      shot_actions.toggle_shot_done()

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Shot should now be marked as done with x and timestamp
      assert.is_truthy(result[3]:match('^## x shot 1'))
      assert.is_truthy(result[3]:match('%(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%)'))
    end)

    it('marks done shot as open (removes x and timestamp)', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## x shot 1 (2026-01-21 14:30:00)',
        'Shot 1 content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 3, 0 })  -- Position in shot 1

      shot_actions.toggle_shot_done()

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Shot should now be open (no x, no timestamp)
      assert.are.equal('## shot 1', result[3])
    end)

    it('removes @ref when marking done shot as open', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## x shot 1 (2026-01-21 14:30:00) @shot-1-20260121_143000',
        'Shot 1 content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 3, 0 })  -- Position in shot 1

      shot_actions.toggle_shot_done()

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Shot should now be open (no x, no timestamp, no @ref)
      assert.are.equal('## shot 1', result[3])
      assert.is_falsy(result[3]:match('@shot%-'))
    end)

    it('works when cursor is in shot content (not header)', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## shot 1',
        'Shot 1 content',
        'More content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 5, 0 })  -- Position in content, not header

      shot_actions.toggle_shot_done()

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Shot should still be marked as done
      assert.is_truthy(result[3]:match('^## x shot 1'))
    end)
  end)

  describe('undo_latest_sent_shot', function()
    it('undoes the marking of the latest sent shot', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## x shot 2 (2026-01-21 15:00:00)',
        'Shot 2 content',
        '',
        '## x shot 1 (2026-01-21 14:30:00)',
        'Shot 1 content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      shot_actions.undo_latest_sent_shot()

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Shot 2 (latest timestamp) should be undone, shot 1 should remain done
      assert.are.equal('## shot 2', result[3])
      assert.is_truthy(result[6]:match('^## x shot 1'))
    end)

    it('does nothing when no sent shots exist', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## shot 1',
        'Shot 1 content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      shot_actions.undo_latest_sent_shot()

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Nothing should change
      assert.are.equal('## shot 1', result[3])
    end)

    it('correctly identifies latest by timestamp not by line order', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      -- Shot 1 has later timestamp but is lower in the file
      local lines = {
        '# Test Title',
        '',
        '## x shot 2 (2026-01-21 10:00:00)',
        'Shot 2 content',
        '',
        '## x shot 1 (2026-01-21 15:00:00)',
        'Shot 1 content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      shot_actions.undo_latest_sent_shot()

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Shot 1 (latest timestamp) should be undone, shot 2 should remain done
      assert.is_truthy(result[3]:match('^## x shot 2'))
      assert.are.equal('## shot 1', result[6])
    end)

    it('removes @ref when undoing latest sent shot', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## x shot 1 (2026-01-21 14:30:00) @shot-1-20260121_143000',
        'Shot 1 content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      shot_actions.undo_latest_sent_shot()

      local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Shot should be open with no x, no timestamp, no @ref
      assert.are.equal('## shot 1', result[3])
      assert.is_falsy(result[3]:match('@shot%-'))
    end)
  end)

  describe('goto_latest_sent_shot', function()
    it('finds shots with @ref format', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## x shot 1 (2026-01-21 14:30:00) @shot-1-20260121_143000',
        'Shot 1 content',
        '',
        '## x shot 2 (2026-01-21 15:00:00) @shot-2-20260121_150000',
        'Shot 2 content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      shot_actions.goto_latest_sent_shot()

      -- Should jump to shot 2 (latest timestamp)
      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.are.equal(6, cursor[1])
    end)

    it('finds mix of old and new format shots', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## x shot 1 (2026-01-21 14:30:00)',  -- old format
        'Shot 1 content',
        '',
        '## x shot 2 (2026-01-21 15:00:00) @shot-2-20260121_150000',  -- new format
        'Shot 2 content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      shot_actions.goto_latest_sent_shot()

      -- Should jump to shot 2 (latest timestamp)
      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.are.equal(6, cursor[1])
    end)
  end)

  describe('goto_prev_sent_shot and goto_next_sent_shot', function()
    it('navigates through shots with @ref format', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## x shot 1 (2026-01-21 14:30:00) @shot-1-20260121_143000',
        'Shot 1 content',
        '',
        '## x shot 2 (2026-01-21 15:00:00) @shot-2-20260121_150000',
        'Shot 2 content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      -- Start at shot 1
      vim.api.nvim_win_set_cursor(0, { 3, 0 })

      -- Go to next (should go to shot 2)
      shot_actions.goto_next_sent_shot()
      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.are.equal(6, cursor[1])

      -- Go to prev (should go back to shot 1)
      shot_actions.goto_prev_sent_shot()
      cursor = vim.api.nvim_win_get_cursor(0)
      assert.are.equal(3, cursor[1])
    end)

    it('navigates through mix of old and new format', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test Title',
        '',
        '## x shot 1 (2026-01-21 14:30:00)',  -- old format
        'Shot 1 content',
        '',
        '## x shot 2 (2026-01-21 15:00:00) @shot-2-20260121_150000',  -- new format
        'Shot 2 content',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_current_buf(bufnr)

      -- Start at shot 1 (old format)
      vim.api.nvim_win_set_cursor(0, { 3, 0 })

      -- Go to next (should go to shot 2 with new format)
      shot_actions.goto_next_sent_shot()
      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.are.equal(6, cursor[1])

      -- Go to prev (should go back to shot 1 with old format)
      shot_actions.goto_prev_sent_shot()
      cursor = vim.api.nvim_win_get_cursor(0)
      assert.are.equal(3, cursor[1])
    end)
  end)

  -- Regression: after < >l opens a main-worktree shotfile from a numbered
  -- worktree (cd-to-main + edit), < >n must find the buffer as a shotfile and
  -- create a new shot. Before the < >l cd fix, cwd stayed in the worktree so
  -- is_shooter_file returned false and the require_shotfile guard silently
  -- dropped < >n.
  describe('new shot after opening main shotfile from a worktree', function()
    local base = vim.fn.expand('~') .. '/.cache/shooter_flow_test'
    local main_root = base .. '/main'
    local wt_root = base .. '/wt_1'
    local shotfile
    local prev_cwd

    before_each(function()
      prev_cwd = vim.fn.getcwd()
      os.execute('rm -rf ' .. base)
      os.execute('mkdir -p ' .. main_root .. '/.hal/util/shooter/shotfiles')
      os.execute('git -C ' .. main_root .. ' init -q -b main')
      os.execute('git -C ' .. main_root .. ' -c user.email=t@t -c user.name=t '
        .. 'commit -q --allow-empty -m init')
      os.execute('git -C ' .. main_root .. ' worktree add -q -b other '
        .. wt_root .. ' >/dev/null 2>&1')
      shotfile = main_root .. '/.hal/util/shooter/shotfiles/thing.md'
      local f = io.open(shotfile, 'w')
      f:write('# thing\n\n## shot 1 existing\n')
      f:close()
    end)

    after_each(function()
      vim.cmd('cd ' .. vim.fn.fnameescape(prev_cwd))
      vim.cmd('silent! %bdelete!')
      os.execute('git -C ' .. main_root .. ' worktree remove -f ' .. wt_root
        .. ' >/dev/null 2>&1')
      os.execute('rm -rf ' .. base)
    end)

    it('< >l cds to main then < >n adds a shot to the main shotfile', function()
      vim.cmd('cd ' .. wt_root)
      files.open_shotfile(shotfile)
      assert.truthy(vim.fn.getcwd():match('/main$'),
        'cwd should switch to main worktree')
      assert.truthy(files.is_shooter_file(),
        'current buffer should register as a shotfile after cd+edit')

      shot_actions.create_new_shot()
      vim.cmd('stopinsert')

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local has_shot_2 = false
      for _, line in ipairs(lines) do
        if line:match('^## shot 2') then has_shot_2 = true; break end
      end
      assert.is_true(has_shot_2, 'create_new_shot should have inserted shot 2')
    end)
  end)
end)
