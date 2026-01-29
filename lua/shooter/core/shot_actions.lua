-- Shot action functions for shooter.nvim
-- Create, delete, and manipulate shots

local utils = require('shooter.utils')
local shots = require('shooter.core.shots')

local M = {}

-- Find the insertion point for new shots (after title, before first shot or orphan text)
-- Returns: insert_line, needs_blank_before (whether to add blank line before header)
local function find_insertion_line(bufnr)
  local lines = utils.get_buf_lines(bufnr, 0, -1)

  -- Find the title line (# ...)
  local title_line = nil
  for i, line in ipairs(lines) do
    if line:match('^#%s+[^#]') then
      title_line = i
      break
    end
  end

  -- If no title, insert at line 1
  if not title_line then
    return 1, true
  end

  -- Find the first shot header after title
  local first_shot_line = nil
  for i = title_line + 1, #lines do
    if lines[i]:match('^##%s+x?%s*shot') then
      first_shot_line = i
      break
    end
  end

  -- Check for orphan text between title and first shot (or end of file)
  local search_end = first_shot_line and (first_shot_line - 1) or #lines
  local orphan_start = nil

  for i = title_line + 1, search_end do
    local line = lines[i]
    -- Non-blank text = orphan text (should become part of new shot)
    if not line:match('^%s*$') then
      orphan_start = i
      break
    end
  end

  if orphan_start then
    -- Insert above orphan text so it becomes part of the new shot
    local prev_line = lines[orphan_start - 1] or ''
    local needs_blank = not prev_line:match('^%s*$')
    return orphan_start, needs_blank
  end

  if first_shot_line then
    -- Insert before first shot
    local prev_line = lines[first_shot_line - 1] or ''
    local needs_blank = not prev_line:match('^%s*$')
    return first_shot_line, needs_blank
  end

  -- No shots and no orphan text, insert after title
  local next_line = lines[title_line + 1] or ''
  local needs_blank = not next_line:match('^%s*$')
  return title_line + 1, needs_blank
end

-- Create a new shot at the top (below title, above other shots)
function M.create_new_shot()
  local bufnr = 0
  local next_num = shots.get_next_shot_number(bufnr)
  local insert_line, needs_blank_before = find_insertion_line(bufnr)

  -- Build the new shot header
  local shot_header = '## shot ' .. next_num

  -- Insert new shot at the top (after title)
  -- Structure: [blank before], header, blank (cursor), blank (spacing below)
  local lines_to_add
  local cursor_offset
  if needs_blank_before then
    lines_to_add = { '', shot_header, '', '' }
    cursor_offset = 2  -- cursor on first blank after header
  else
    lines_to_add = { shot_header, '', '' }
    cursor_offset = 1  -- cursor on first blank after header
  end
  utils.set_buf_lines(bufnr, insert_line - 1, insert_line - 1, lines_to_add)

  -- Position cursor on the first blank line after header (blank below for spacing)
  vim.api.nvim_win_set_cursor(0, { insert_line + cursor_offset, 0 })
  vim.cmd('startinsert')

  utils.echo('Created shot ' .. next_num)
end

-- Create new shot and start whisper for dictation
function M.create_new_shot_with_whisper()
  local bufnr = 0
  local next_num = shots.get_next_shot_number(bufnr)
  local insert_line, needs_blank_before = find_insertion_line(bufnr)

  -- Build the new shot header
  local shot_header = '## shot ' .. next_num

  -- Insert new shot at the top (after title)
  -- Structure: [blank before], header, blank (cursor), blank (spacing below)
  local lines_to_add
  local cursor_offset
  if needs_blank_before then
    lines_to_add = { '', shot_header, '', '' }
    cursor_offset = 2  -- cursor on first blank after header
  else
    lines_to_add = { shot_header, '', '' }
    cursor_offset = 1  -- cursor on first blank after header
  end
  utils.set_buf_lines(bufnr, insert_line - 1, insert_line - 1, lines_to_add)

  -- Position cursor on the first blank line after header (blank below for spacing)
  vim.api.nvim_win_set_cursor(0, { insert_line + cursor_offset, 0 })
  vim.cmd('startinsert')

  -- Start whisper after a short delay to ensure insert mode is active
  vim.defer_fn(function()
    if vim.fn.exists(':GpWhisper') == 2 then
      vim.cmd('GpWhisper')
    else
      utils.echo('GpWhisper not available')
    end
  end, 100)

  utils.echo('Created shot ' .. next_num .. ' - speak now')
end

-- Delete the last created shot (highest numbered, not executed)
function M.delete_last_shot()
  local bufnr = 0
  local lines = utils.get_buf_lines(bufnr, 0, -1)

  -- Find the highest shot number and its line
  local max_shot = 0
  local max_shot_line = nil
  local is_executed = false

  for i, line in ipairs(lines) do
    local shot_num = line:match('^##%s+x?%s*shot%s+(%d+)')
    if shot_num then
      local num = tonumber(shot_num)
      if num and num > max_shot then
        max_shot = num
        max_shot_line = i
        is_executed = line:match('^##%s+x%s+shot') ~= nil
      end
    end
  end

  if not max_shot_line then
    utils.echo('No shots found to delete')
    return
  end

  -- Check if already being worked on
  if is_executed then
    utils.echo('Cannot delete shot ' .. max_shot .. ' - already being worked on')
    return
  end

  -- Find the shot's end (next shot header or end of file)
  local shot_end = #lines
  for i = max_shot_line + 1, #lines do
    if lines[i]:match('^##%s+x?%s*shot') then
      shot_end = i - 1
      break
    end
  end

  -- Find the shot's start (include preceding blank line if exists)
  local shot_start = max_shot_line
  if max_shot_line > 1 and lines[max_shot_line - 1]:match('^%s*$') then
    shot_start = max_shot_line - 1
  end

  -- Delete the range
  utils.set_buf_lines(bufnr, shot_start - 1, shot_end, {})

  -- Ensure blank line after title if next line is a shot header
  local new_lines = utils.get_buf_lines(bufnr, 0, -1)
  local title_line = nil
  for i, line in ipairs(new_lines) do
    if line:match('^#%s+[^#]') then
      title_line = i
      break
    end
  end

  if title_line and title_line < #new_lines then
    local next_line = new_lines[title_line + 1]
    if next_line and next_line:match('^##%s+x?%s*shot') then
      -- No blank line between title and first shot, insert one
      utils.set_buf_lines(bufnr, title_line, title_line, { '' })
    end
  end

  utils.echo('Deleted shot ' .. max_shot)
end

-- Navigate to next open shot
function M.goto_next_open_shot()
  local bufnr = 0
  local cursor_line = utils.get_cursor()[1]
  local open_shots = shots.find_open_shots(bufnr)

  if #open_shots == 0 then
    utils.echo('No open shots')
    return
  end

  -- Find the next open shot after cursor
  for _, shot in ipairs(open_shots) do
    if shot.header_line > cursor_line then
      vim.api.nvim_win_set_cursor(0, { shot.header_line, 0 })
      local shot_num = shots.parse_shot_header(
        utils.get_buf_lines(bufnr, shot.header_line - 1, shot.header_line)[1]
      )
      utils.echo('Shot ' .. shot_num)
      return
    end
  end

  -- Wrap around to first open shot
  local first = open_shots[1]
  vim.api.nvim_win_set_cursor(0, { first.header_line, 0 })
  local shot_num = shots.parse_shot_header(
    utils.get_buf_lines(bufnr, first.header_line - 1, first.header_line)[1]
  )
  utils.echo('Shot ' .. shot_num .. ' (wrapped)')
end

-- Navigate to previous open shot
function M.goto_prev_open_shot()
  local bufnr = 0
  local cursor_line = utils.get_cursor()[1]
  local open_shots = shots.find_open_shots(bufnr)

  if #open_shots == 0 then
    utils.echo('No open shots')
    return
  end

  -- Find the previous open shot before cursor
  for i = #open_shots, 1, -1 do
    local shot = open_shots[i]
    if shot.header_line < cursor_line then
      vim.api.nvim_win_set_cursor(0, { shot.header_line, 0 })
      local shot_num = shots.parse_shot_header(
        utils.get_buf_lines(bufnr, shot.header_line - 1, shot.header_line)[1]
      )
      utils.echo('Shot ' .. shot_num)
      return
    end
  end

  -- Wrap around to last open shot
  local last = open_shots[#open_shots]
  vim.api.nvim_win_set_cursor(0, { last.header_line, 0 })
  local shot_num = shots.parse_shot_header(
    utils.get_buf_lines(bufnr, last.header_line - 1, last.header_line)[1]
  )
  utils.echo('Shot ' .. shot_num .. ' (wrapped)')
end

-- Toggle shot done status (mark/unmark with x and timestamp)
function M.toggle_shot_done()
  local bufnr = 0
  local cursor_line = utils.get_cursor()[1]

  -- Find the current shot
  local shot_start, _, header_line = shots.find_current_shot(bufnr, cursor_line)
  if not shot_start then
    utils.echo('Not in a shot')
    return
  end

  local line = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
  local shot_num = shots.parse_shot_header(line)

  -- Check if already marked as done (has x)
  local config = require('shooter.config')
  local is_done = line:match(config.get('patterns.executed_shot_header')) ~= nil

  if is_done then
    -- Remove x and timestamp → make open
    -- Pattern: ## x shot N (date) → ## shot N
    line = line:gsub('^(##)%s+x%s+shot', '%1 shot')
    line = line:gsub('%s*%(%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d%)%s*$', '')
    utils.set_buf_lines(bufnr, header_line - 1, header_line, { line })
    utils.echo('Shot ' .. shot_num .. ' marked open')
  else
    -- Add x and timestamp → make done
    local timestamp = utils.get_timestamp()
    line = line:gsub('^(##)%s+shot', '%1 x shot')
    line = line .. ' (' .. timestamp .. ')'
    utils.set_buf_lines(bufnr, header_line - 1, header_line, { line })
    utils.echo('Shot ' .. shot_num .. ' marked done')
  end

  -- Save the file
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname ~= '' then
    vim.cmd('write')
  end
end

-- Navigate to the most recently sent/executed shot (by timestamp)
function M.goto_latest_sent_shot()
  local bufnr = 0
  local config = require('shooter.config')
  local lines = utils.get_buf_lines(bufnr, 0, -1)

  local latest_line = nil
  local latest_timestamp = nil

  for i, line in ipairs(lines) do
    -- Match executed shot headers with timestamp
    if line:match(config.get('patterns.executed_shot_header')) then
      -- Extract timestamp: (YYYY-MM-DD HH:MM:SS)
      local timestamp = line:match('%((%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)%)%s*$')
      if timestamp then
        if not latest_timestamp or timestamp > latest_timestamp then
          latest_timestamp = timestamp
          latest_line = i
        end
      end
    end
  end

  if not latest_line then
    utils.echo('No sent shots found')
    return
  end

  vim.api.nvim_win_set_cursor(0, { latest_line, 0 })
  local shot_num = shots.parse_shot_header(lines[latest_line])
  utils.echo('Latest sent: Shot ' .. shot_num .. ' (' .. latest_timestamp .. ')')
end

-- Get all sent shots sorted by timestamp (oldest first)
local function get_sent_shots_sorted(bufnr)
  local config = require('shooter.config')
  local lines = utils.get_buf_lines(bufnr, 0, -1)
  local sent = {}
  for i, line in ipairs(lines) do
    if line:match(config.get('patterns.executed_shot_header')) then
      local ts = line:match('%((%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)%)%s*$')
      if ts then table.insert(sent, { line_num = i, timestamp = ts, shot_num = shots.parse_shot_header(line) }) end
    end
  end
  table.sort(sent, function(a, b) return a.timestamp < b.timestamp end)
  return sent
end

-- Navigate to previous (older) sent shot
function M.goto_prev_sent_shot()
  local bufnr = 0
  local cursor_line = utils.get_cursor()[1]
  local sent = get_sent_shots_sorted(bufnr)
  if #sent == 0 then utils.echo('No sent shots'); return end

  -- Find current position in sent shot history
  local current_idx = nil
  for i, s in ipairs(sent) do
    if s.line_num == cursor_line then current_idx = i; break end
  end

  local target
  if current_idx and current_idx > 1 then
    target = sent[current_idx - 1]
  else
    target = sent[#sent]  -- Wrap to newest if at oldest or not on a sent shot
  end

  vim.api.nvim_win_set_cursor(0, { target.line_num, 0 })
  utils.echo('Shot ' .. target.shot_num .. ' (' .. target.timestamp .. ')')
end

-- Navigate to next (newer) sent shot
function M.goto_next_sent_shot()
  local bufnr = 0
  local cursor_line = utils.get_cursor()[1]
  local sent = get_sent_shots_sorted(bufnr)
  if #sent == 0 then utils.echo('No sent shots'); return end

  -- Find current position in sent shot history
  local current_idx = nil
  for i, s in ipairs(sent) do
    if s.line_num == cursor_line then current_idx = i; break end
  end

  local target
  if current_idx and current_idx < #sent then
    target = sent[current_idx + 1]
  else
    target = sent[1]  -- Wrap to oldest if at newest or not on a sent shot
  end

  vim.api.nvim_win_set_cursor(0, { target.line_num, 0 })
  utils.echo('Shot ' .. target.shot_num .. ' (' .. target.timestamp .. ')')
end

-- Undo the marking of the latest sent shot (change ## x shot ... back to ## shot ...)
function M.undo_latest_sent_shot()
  local bufnr = 0
  local config = require('shooter.config')
  local lines = utils.get_buf_lines(bufnr, 0, -1)

  local latest_line = nil
  local latest_timestamp = nil

  for i, line in ipairs(lines) do
    -- Match executed shot headers with timestamp
    if line:match(config.get('patterns.executed_shot_header')) then
      -- Extract timestamp: (YYYY-MM-DD HH:MM:SS)
      local timestamp = line:match('%((%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)%)%s*$')
      if timestamp then
        if not latest_timestamp or timestamp > latest_timestamp then
          latest_timestamp = timestamp
          latest_line = i
        end
      end
    end
  end

  if not latest_line then
    utils.echo('No sent shots found to undo')
    return
  end

  local line = lines[latest_line]
  local shot_num = shots.parse_shot_header(line)

  -- Remove x and timestamp → make open
  -- Pattern: ## x shot N (date) → ## shot N
  line = line:gsub('^(##)%s+x%s+shot', '%1 shot')
  line = line:gsub('%s*%(%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d%)%s*$', '')
  utils.set_buf_lines(bufnr, latest_line - 1, latest_line, { line })

  -- Move cursor to the undone shot
  vim.api.nvim_win_set_cursor(0, { latest_line, 0 })

  -- Save the file
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname ~= '' then
    vim.cmd('write')
  end

  utils.echo('Undone marking: Shot ' .. shot_num .. ' is now open')
end

-- Yank current shot content to clipboard and mark as done
function M.yank_shot()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = utils.get_cursor()[1]
  local start_line, end_line, header_line = shots.find_current_shot(bufnr, cursor_line)
  if not start_line then
    utils.echo('No shot found under cursor')
    return
  end

  -- Get shot info
  local content = shots.get_shot_content(bufnr, start_line, end_line)
  local header_text = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
  local shot_num = shots.parse_shot_header(header_text) or '?'

  -- Mark shot as done
  shots.mark_shot_executed(bufnr, header_line)

  -- Yank to clipboard
  vim.fn.setreg('+', content)
  vim.fn.setreg('"', content)
  utils.echo('Yanked shot ' .. shot_num .. ' and marked done')
end

-- Extract subtask under cursor into a new shot
-- Finds ### heading at or above cursor, extracts until next ### or end of shot
function M.extract_subtask()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = utils.get_cursor()[1]
  local shot_start, shot_end = shots.find_current_shot(bufnr, cursor_line)
  if not shot_start then
    utils.echo('No shot found under cursor')
    return
  end

  local lines = utils.get_buf_lines(bufnr, shot_start - 1, shot_end)
  local subtask_start, subtask_end = nil, nil

  -- Find ### heading at or before cursor (relative to shot)
  local rel_cursor = cursor_line - shot_start + 1
  for i = rel_cursor, 1, -1 do
    if lines[i] and lines[i]:match('^###%s+') then
      subtask_start = i
      break
    end
  end

  if not subtask_start then
    utils.echo('No subtask (### heading) found at or above cursor')
    return
  end

  -- Find end of subtask (next ### or end of shot)
  for i = subtask_start + 1, #lines do
    if lines[i]:match('^###%s+') then
      subtask_end = i - 1
      break
    end
  end
  subtask_end = subtask_end or #lines

  -- Trim trailing blank lines from subtask
  while subtask_end > subtask_start and lines[subtask_end]:match('^%s*$') do
    subtask_end = subtask_end - 1
  end

  -- Extract subtask content (skip the ### header itself for the new shot body)
  local subtask_lines = {}
  for i = subtask_start + 1, subtask_end do
    table.insert(subtask_lines, lines[i])
  end
  local subtask_title = lines[subtask_start]:match('^###%s+(.+)$') or 'extracted'

  -- Create new shot with subtask content
  -- Format: ## shot N, then UPPERCASED TITLE on next line, then content
  local next_num = shots.get_next_shot_number(bufnr)
  local insert_line, needs_blank = find_insertion_line(bufnr)
  local new_lines = {}
  if needs_blank then table.insert(new_lines, '') end
  table.insert(new_lines, '## shot ' .. next_num)
  table.insert(new_lines, subtask_title:upper())
  for _, line in ipairs(subtask_lines) do
    table.insert(new_lines, line)
  end
  table.insert(new_lines, '')
  utils.set_buf_lines(bufnr, insert_line - 1, insert_line - 1, new_lines)

  -- Remove subtask from original shot (adjust for inserted lines)
  local offset = #new_lines
  local del_start = shot_start + subtask_start - 1 + offset
  local del_end = shot_start + subtask_end - 1 + offset
  -- Include leading blank line if exists
  if subtask_start > 1 and lines[subtask_start - 1]:match('^%s*$') then
    del_start = del_start - 1
  end
  utils.set_buf_lines(bufnr, del_start - 1, del_end, {})

  vim.cmd('write')

  -- Jump to end of extracted shot (line before trailing blank) and enter insert mode
  local shot_end_line = insert_line + #new_lines - 2  -- -1 for trailing blank, -1 for 0-index adjustment
  if needs_blank then shot_end_line = shot_end_line end  -- blank at start already counted
  vim.api.nvim_win_set_cursor(0, { shot_end_line, 0 })
  vim.cmd('normal! $')
  vim.cmd('startinsert!')
  utils.echo('Extracted subtask to shot ' .. next_num)
end

-- Extract current line into a new shot
function M.extract_line()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = utils.get_cursor()[1]
  local shot_start, shot_end = shots.find_current_shot(bufnr, cursor_line)
  if not shot_start then
    utils.echo('No shot found under cursor')
    return
  end

  -- Get the current line content
  local lines = utils.get_buf_lines(bufnr, cursor_line - 1, cursor_line)
  local line_content = lines[1]
  if not line_content or line_content:match('^%s*$') then
    utils.echo('Current line is empty')
    return
  end
  -- Don't extract the shot header itself
  if line_content:match('^##%s+x?%s*shot') then
    utils.echo('Cannot extract shot header')
    return
  end

  -- Create new shot with line content (uppercased as title)
  local next_num = shots.get_next_shot_number(bufnr)
  local insert_line, needs_blank = find_insertion_line(bufnr)
  local new_lines = {}
  if needs_blank then table.insert(new_lines, '') end
  table.insert(new_lines, '## shot ' .. next_num)
  table.insert(new_lines, line_content:upper())
  table.insert(new_lines, '')
  utils.set_buf_lines(bufnr, insert_line - 1, insert_line - 1, new_lines)

  -- Remove line from original shot (adjust for inserted lines)
  local del_line = cursor_line + #new_lines
  utils.set_buf_lines(bufnr, del_line - 1, del_line, {})

  vim.cmd('write')

  -- Jump to end of extracted shot (the TITLE line) and enter insert mode
  local shot_end_line = insert_line + #new_lines - 2  -- -1 for trailing blank, -1 for 0-index
  vim.api.nvim_win_set_cursor(0, { shot_end_line, 0 })
  vim.cmd('normal! $')
  vim.cmd('startinsert!')
  utils.echo('Extracted line to shot ' .. next_num)
end

return M
