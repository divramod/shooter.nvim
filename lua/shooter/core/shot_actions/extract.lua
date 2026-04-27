-- Yank current shot, extract subtask block, extract single line.
-- All three create a new shot from a piece of the current shot.

local utils = require('shooter.utils')
local shots = require('shooter.core.shots')
local insertion = require('shooter.core.shot_actions.insertion')

local M = {}

-- Yank current shot content to clipboard and mark as done.
function M.yank_shot()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = utils.get_cursor()[1]
  local start_line, end_line, header_line = shots.find_current_shot(bufnr, cursor_line)
  if not start_line then
    utils.echo('No shot found under cursor')
    return
  end

  -- Capture the original "## shot N ..." header BEFORE marking done so the
  -- yanked text retains the open form, not the executed form.
  local content = shots.get_shot_content(bufnr, start_line, end_line)
  local header_text = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
  local shot_num = shots.parse_shot_header(header_text) or '?'

  shots.mark_shot_executed(bufnr, header_line)

  local renumber_helper = require('shooter.tmux.renumber_helper')
  local new_start, _, new_header = renumber_helper.renumber_and_find_shot(bufnr, start_line, end_line)
  if new_header then
    vim.api.nvim_win_set_cursor(0, { new_header, 0 })
  end

  local yank_text = content ~= '' and (header_text .. '\n' .. content) or header_text
  vim.fn.setreg('+', yank_text)
  vim.fn.setreg('"', yank_text)
  utils.echo('Yanked shot ' .. shot_num .. ' and marked done')
end

-- Extract subtask under cursor into a new shot.
-- Finds ### heading at or above cursor, extracts until next ### or end of shot.
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

  -- Find ### heading at or before cursor (relative to shot).
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

  -- Find end of subtask (next ### or end of shot).
  for i = subtask_start + 1, #lines do
    if lines[i]:match('^###%s+') then
      subtask_end = i - 1
      break
    end
  end
  subtask_end = subtask_end or #lines

  while subtask_end > subtask_start and lines[subtask_end]:match('^%s*$') do
    subtask_end = subtask_end - 1
  end

  -- Extract subtask content (skip the ### header — used as title for new shot).
  local subtask_lines = {}
  for i = subtask_start + 1, subtask_end do
    table.insert(subtask_lines, lines[i])
  end
  local subtask_title = lines[subtask_start]:match('^###%s+(.+)$') or 'extracted'

  -- Format: ## shot N \n UPPERCASED TITLE \n content
  local next_num = shots.get_next_shot_number(bufnr)
  local insert_line, needs_blank = insertion.find_insertion_line(bufnr)
  local new_lines = {}
  if needs_blank then table.insert(new_lines, '') end
  table.insert(new_lines, '## shot ' .. next_num)
  table.insert(new_lines, subtask_title:upper())
  for _, line in ipairs(subtask_lines) do
    table.insert(new_lines, line)
  end
  table.insert(new_lines, '')
  utils.set_buf_lines(bufnr, insert_line - 1, insert_line - 1, new_lines)

  -- Remove subtask from original shot (adjust for inserted lines).
  local offset = #new_lines
  local del_start = shot_start + subtask_start - 1 + offset
  local del_end = shot_start + subtask_end - 1 + offset
  if subtask_start > 1 and lines[subtask_start - 1]:match('^%s*$') then
    del_start = del_start - 1
  end
  utils.set_buf_lines(bufnr, del_start - 1, del_end, {})

  vim.cmd('silent! write')

  -- Jump to end of extracted shot (line before trailing blank) and enter insert mode.
  local shot_end_line = insert_line + #new_lines - 2
  if needs_blank then shot_end_line = shot_end_line end
  vim.api.nvim_win_set_cursor(0, { shot_end_line, 0 })
  vim.cmd('normal! $')
  vim.cmd('startinsert!')
  utils.echo('Extracted subtask to shot ' .. next_num)
end

-- Extract current line into a new shot.
function M.extract_line()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = utils.get_cursor()[1]
  local shot_start, shot_end = shots.find_current_shot(bufnr, cursor_line)
  if not shot_start then
    utils.echo('No shot found under cursor')
    return
  end

  local lines = utils.get_buf_lines(bufnr, cursor_line - 1, cursor_line)
  local line_content = lines[1]
  if not line_content or line_content:match('^%s*$') then
    utils.echo('Current line is empty')
    return
  end
  if line_content:match('^##%s+x?%s*shot') then
    utils.echo('Cannot extract shot header')
    return
  end

  -- Format: ## shot N \n UPPERCASED LINE
  local next_num = shots.get_next_shot_number(bufnr)
  local insert_line, needs_blank = insertion.find_insertion_line(bufnr)
  local new_lines = {}
  if needs_blank then table.insert(new_lines, '') end
  table.insert(new_lines, '## shot ' .. next_num)
  table.insert(new_lines, line_content:upper())
  table.insert(new_lines, '')
  utils.set_buf_lines(bufnr, insert_line - 1, insert_line - 1, new_lines)

  local del_line = cursor_line + #new_lines
  utils.set_buf_lines(bufnr, del_line - 1, del_line, {})

  vim.cmd('silent! write')

  local shot_end_line = insert_line + #new_lines - 2
  vim.api.nvim_win_set_cursor(0, { shot_end_line, 0 })
  vim.cmd('normal! $')
  vim.cmd('startinsert!')
  utils.echo('Extracted line to shot ' .. next_num)
end

return M
