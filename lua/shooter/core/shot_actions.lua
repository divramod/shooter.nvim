-- Shot action functions for shooter.nvim
-- Create, delete, and manipulate shots

local utils = require('shooter.utils')
local shots = require('shooter.core.shots')

local M = {}

-- Find the insertion point for new shots (after title + meta area, before first shot)
-- The meta area is any non-shot content between the title and the first shot header.
-- Returns: insert_line, needs_blank_before, has_content_below
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
  if not title_line then return 1, true, false end

  -- Find the first shot header after title
  local first_shot_line = nil
  for i = title_line + 1, #lines do
    if lines[i]:match('^##%s+x?%s*shot') then
      first_shot_line = i
      break
    end
  end

  if first_shot_line then
    -- Insert before first shot (content below = true)
    local prev_line = lines[first_shot_line - 1] or ''
    return first_shot_line, not prev_line:match('^%s*$'), true
  end

  -- No shots found — find end of meta area (last non-blank line after title)
  local last_content_line = title_line
  for i = title_line + 1, #lines do
    if not lines[i]:match('^%s*$') then
      last_content_line = i
    end
  end

  -- Insert after the last content line (title or meta area)
  return last_content_line + 1, true, false
end

-- Create a new shot at the top (below title, above other shots)
function M.create_new_shot()
  local bufnr = 0
  local next_num = shots.get_next_shot_number(bufnr)
  local insert_line, needs_blank_before, has_content_below = find_insertion_line(bufnr)

  local shot_header = '## shot ' .. next_num .. ' '
  local lines_to_add
  local cursor_offset

  -- Structure: [blank before], header, [blank separator if content below]
  if needs_blank_before then
    lines_to_add = has_content_below and { '', shot_header, '' } or { '', shot_header }
    cursor_offset = 2
  else
    lines_to_add = has_content_below and { shot_header, '' } or { shot_header }
    cursor_offset = 1
  end
  utils.set_buf_lines(bufnr, insert_line - 1, insert_line - 1, lines_to_add)

  -- Position cursor at end of header line (for typing header description)
  local header_offset = needs_blank_before and 1 or 0
  vim.api.nvim_win_set_cursor(0, { insert_line + header_offset, 0 })
  vim.cmd('startinsert!')
  utils.echo('Created shot ' .. next_num)
end

-- Create new shot and start whisper for dictation
function M.create_new_shot_with_whisper()
  local bufnr = 0
  local next_num = shots.get_next_shot_number(bufnr)
  local insert_line, needs_blank_before, has_content_below = find_insertion_line(bufnr)

  local shot_header = '## shot ' .. next_num .. ' '
  local lines_to_add
  local cursor_offset

  if needs_blank_before then
    lines_to_add = has_content_below and { '', shot_header, '' } or { '', shot_header }
    cursor_offset = 2
  else
    lines_to_add = has_content_below and { shot_header, '' } or { shot_header }
    cursor_offset = 1
  end
  utils.set_buf_lines(bufnr, insert_line - 1, insert_line - 1, lines_to_add)

  -- Position cursor at end of header line (for typing header description)
  local header_offset = needs_blank_before and 1 or 0
  vim.api.nvim_win_set_cursor(0, { insert_line + header_offset, 0 })
  vim.cmd('startinsert!')

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

  -- Ensure blank line before first shot header (after title/meta area)
  local new_lines = utils.get_buf_lines(bufnr, 0, -1)
  for i, line in ipairs(new_lines) do
    if line:match('^##%s+x?%s*shot') then
      if i > 1 and not new_lines[i - 1]:match('^%s*$') then
        utils.set_buf_lines(bufnr, i - 1, i - 1, { '' })
      end
      break
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
  local shot_start, shot_end, header_line = shots.find_current_shot(bufnr, cursor_line)
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
    -- Remove x, timestamp, and @ref → make open
    -- Pattern: ## x shot N (date) @shot-N-... → ## shot N
    line = line:gsub('^(##)%s+x%s+shot', '%1 shot')
    line = line:gsub('%s*%(%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d%)', '')
    line = line:gsub('%s*@[%w%.%-_]+', '')
    line = line:gsub('%s+$', '') -- trim trailing whitespace
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

  -- Renumber and resort shots (open shots top, done shots bottom)
  local renumber_helper = require('shooter.tmux.renumber_helper')
  local new_start, _, new_header = renumber_helper.renumber_and_find_shot(bufnr, shot_start, shot_end)
  if new_header then
    vim.api.nvim_win_set_cursor(0, { new_header, 0 })
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
      -- Extract timestamp - may have @ref after, so don't anchor to end
      local timestamp = line:match('%((%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)%)')
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
-- Supports both old format (no @ref) and new format (with @ref at end)
local function get_sent_shots_sorted(bufnr)
  local config = require('shooter.config')
  local lines = utils.get_buf_lines(bufnr, 0, -1)
  local sent = {}
  for i, line in ipairs(lines) do
    if line:match(config.get('patterns.executed_shot_header')) then
      -- Extract timestamp - may have @ref after, so don't anchor to end
      local ts = line:match('%((%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)%)')
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
      -- Extract timestamp: (YYYY-MM-DD HH:MM:SS) - may have @ref after
      local timestamp = line:match('%((%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)%)')
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

  -- Remove x, timestamp, and @ref → make open
  -- Pattern: ## x shot N (date) @shot-N-... → ## shot N
  line = line:gsub('^(##)%s+x%s+shot', '%1 shot')
  line = line:gsub('%s*%(%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d%)', '')
  line = line:gsub('%s*@shot%-[%d_%-]+', '')
  line = line:gsub('%s+$', '') -- trim trailing whitespace
  utils.set_buf_lines(bufnr, latest_line - 1, latest_line, { line })

  -- Move cursor to the undone shot
  vim.api.nvim_win_set_cursor(0, { latest_line, 0 })

  -- Save the file
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname ~= '' then
    vim.cmd('silent! write')
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

  -- Get shot info — capture header before marking as done so the yanked
  -- text contains the original "## shot N ..." line, not the executed form.
  local content = shots.get_shot_content(bufnr, start_line, end_line)
  local header_text = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
  local shot_num = shots.parse_shot_header(header_text) or '?'

  -- Mark shot as done
  shots.mark_shot_executed(bufnr, header_line)

  -- Renumber and resort shots (open shots top, done shots bottom)
  local renumber_helper = require('shooter.tmux.renumber_helper')
  local new_start, _, new_header = renumber_helper.renumber_and_find_shot(bufnr, start_line, end_line)
  if new_header then
    vim.api.nvim_win_set_cursor(0, { new_header, 0 })
  end

  -- Yank header + body to clipboard.
  local yank_text = content ~= '' and (header_text .. '\n' .. content) or header_text
  vim.fn.setreg('+', yank_text)
  vim.fn.setreg('"', yank_text)
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

  vim.cmd('silent! write')

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

  vim.cmd('silent! write')

  -- Jump to end of extracted shot (the TITLE line) and enter insert mode
  local shot_end_line = insert_line + #new_lines - 2  -- -1 for trailing blank, -1 for 0-index
  vim.api.nvim_win_set_cursor(0, { shot_end_line, 0 })
  vim.cmd('normal! $')
  vim.cmd('startinsert!')
  utils.echo('Extracted line to shot ' .. next_num)
end

-- Show stats for the current shotfile (total, open, closed shots)
function M.file_stats()
  local bufnr = 0
  local all = shots.find_all_shots(bufnr)
  local total = #all
  local closed = 0
  for _, shot in ipairs(all) do
    if shot.is_executed then closed = closed + 1 end
  end
  local open = total - closed

  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local filename = bufname ~= '' and vim.fn.fnamemodify(bufname, ':t') or 'untitled'

end

-- Create a shot from text stored in a file (called via tmux send-keys from another pane)
function M.create_shot_from_file(filepath)
  local content, err = utils.read_file(filepath)
  if not content or content == '' then
    utils.echo('No content to create shot from')
    return
  end

  content = utils.trim(content)
  if content == '' then
    utils.echo('Empty content, no shot created')
    return
  end

  local bufnr = 0
  local next_num = shots.get_next_shot_number(bufnr)
  local insert_line, needs_blank_before, has_content_below = find_insertion_line(bufnr)

  local shot_header = '## shot ' .. next_num
  local content_lines = vim.split(content, '\n')
  local lines_to_add = {}

  if needs_blank_before then
    table.insert(lines_to_add, '')
  end
  table.insert(lines_to_add, shot_header)
  for _, line in ipairs(content_lines) do
    table.insert(lines_to_add, line)
  end
  if has_content_below then
    table.insert(lines_to_add, '')
  end

  utils.set_buf_lines(bufnr, insert_line - 1, insert_line - 1, lines_to_add)

  -- Position cursor on the content (after header)
  local cursor_line = insert_line + (needs_blank_before and 2 or 1)
  vim.api.nvim_win_set_cursor(0, { cursor_line, 0 })

  -- Save the buffer
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname ~= '' then
    vim.cmd('silent! write')
  end

  -- Clean up temp file
  os.remove(filepath)

  utils.echo('Created shot ' .. next_num .. ' from Claude')
end

-- Write a self-contained lua script that creates a shot from a temp file
-- Uses :luafile so it works without requiring the plugin module to be loaded
local function write_shot_creator_script(shot_file, script_file)
  local script = string.format([[
local filepath = "%s"
local f = io.open(filepath, "r")
if not f then return end
local content = f:read("*a")
f:close()
content = vim.trim(content)
if content == "" then return end

local bufnr = 0
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

-- Find title line
local title_line = nil
for i, line in ipairs(lines) do
  if line:match("^#%%s+[^#]") then title_line = i; break end
end

-- Find first shot header
local first_shot = nil
if title_line then
  for i = title_line + 1, #lines do
    if lines[i]:match("^##%%s+x?%%s*shot") then first_shot = i; break end
  end
end

-- Determine next shot number
local max_shot = 0
for _, line in ipairs(lines) do
  local num = line:match("^##%%s+x?%%s*shot%%s+(%%d+)")
  if num then local n = tonumber(num); if n > max_shot then max_shot = n end end
end
local next_num = max_shot + 1

-- Determine insertion point
local insert_line = (title_line or 0) + 1
if first_shot then insert_line = first_shot end

-- Build new shot lines
local content_lines = vim.split(content, "\n")
local new_lines = { "", "## shot " .. next_num }
for _, line in ipairs(content_lines) do
  table.insert(new_lines, line)
end
table.insert(new_lines, "")

vim.api.nvim_buf_set_lines(bufnr, insert_line - 1, insert_line - 1, false, new_lines)
vim.api.nvim_win_set_cursor(0, { insert_line + 2, 0 })

local bufname = vim.api.nvim_buf_get_name(bufnr)
if bufname ~= "" then vim.cmd("write") end

os.remove(filepath)
os.remove("%s")

vim.schedule(function()
  vim.cmd('echon "Created shot ' .. next_num .. ' from Claude"')
end)
]], shot_file, script_file)

  local f = io.open(script_file, 'w')
  if not f then return false end
  f:write(script)
  f:close()
  return true
end

-- Cut text from Claude's ctrl+g editor buffer, close it, and create a shot in the right tmux pane
function M.create_shot_from_claude()
  -- 1. Get all text from current buffer
  local lines = utils.get_buf_lines(0, 0, -1)
  local text = table.concat(lines, '\n')
  text = utils.trim(text)

  if text == '' then
    utils.echo('Buffer is empty, nothing to send')
    return
  end

  -- 2. Save text and a self-contained creator script to temp files
  local tmp_file = '/tmp/shooter-claude-shot.md'
  local script_file = '/tmp/shooter-claude-shot-cmd.lua'
  local ok, err = utils.write_file(tmp_file, text)
  if not ok then
    utils.echo('Failed to write temp file: ' .. (err or ''))
    return
  end
  if not write_shot_creator_script(tmp_file, script_file) then
    utils.echo('Failed to write script file')
    os.remove(tmp_file)
    return
  end

  -- 3. Find the right tmux pane
  local right_pane = vim.fn.system('tmux display-message -p -t "{right}" "#{pane_id}"')
  right_pane = vim.trim(right_pane)

  if right_pane == '' or right_pane:match('can.t') or right_pane:match('error') then
    utils.echo('No right pane found')
    os.remove(tmp_file)
    os.remove(script_file)
    return
  end

  -- 4. Send Escape to ensure normal mode, then run self-contained script via :luafile
  vim.fn.system('tmux send-keys -t ' .. right_pane .. ' Escape')
  vim.fn.system(
    'tmux send-keys -t ' .. right_pane
    .. ' ":luafile ' .. script_file .. '" Enter'
  )

  -- 5. Clear the buffer (so Claude gets empty input back)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {})

  -- 6. Switch focus to right pane (before wq since nvim exits after wq)
  vim.fn.system('tmux select-pane -t ' .. right_pane)

  -- 7. Write and quit (returns to Claude CLI with empty input)
  vim.cmd('wq')
end

return M
