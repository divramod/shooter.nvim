-- Telescope action handlers for shooter.nvim
local M = {}

local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local finders = require('telescope.finders')

local utils = require('shooter.utils')

-- Helper: Get files for telescope picker
local function get_prompt_files()
  local cwd = vim.fn.getcwd()
  local prompts_dir = cwd .. '/plans/prompts'
  local file_list = vim.fn.globpath(prompts_dir, '**/*.md', false, true)
  local results = {}
  for _, file in ipairs(file_list) do
    local display = file:gsub('^' .. vim.pesc(prompts_dir) .. '/', '')
    table.insert(results, { display = display, path = file })
  end
  return results
end

-- Send shot to claude pane (single shot)
function M.send_shot(prompt_bufnr, pane_num, entry)
  pane_num = pane_num or 1

  if not entry then
    entry = action_state.get_selected_entry()
  end

  if not entry or not entry.value then
    utils.echo('No shot selected')
    return
  end

  actions.close(prompt_bufnr)

  local shot_data = entry.value
  local is_current_file = shot_data.is_current_file
  local target_file = shot_data.target_file

  -- If not in the target file, open it first
  if not is_current_file then
    vim.cmd('edit ' .. vim.fn.fnameescape(target_file))
  end

  -- Move cursor to the shot
  vim.api.nvim_win_set_cursor(0, {shot_data.header_line, 0})

  -- Send using new shooter.tmux module (includes history saving)
  require('shooter.tmux').send_current_shot(pane_num)
end

-- Send multiple shots to claude pane
function M.send_multiple_shots(prompt_bufnr, pane_num)
  pane_num = pane_num or 1
  local multi = action_state.get_current_picker(prompt_bufnr):get_multi_selection()

  -- If only one or no multi-select, use single shot
  if #multi <= 1 then
    M.send_shot(prompt_bufnr, pane_num)
    return
  end

  actions.close(prompt_bufnr)

  local first = multi[1].value
  if not first.is_current_file then
    vim.cmd('edit ' .. vim.fn.fnameescape(first.target_file))
  end

  -- Build shot_infos array
  local shot_infos = {}
  for _, e in ipairs(multi) do
    table.insert(shot_infos, {
      start_line = e.value.start_line,
      end_line = e.value.end_line,
      header_line = e.value.header_line,
    })
  end
  table.sort(shot_infos, function(a, b) return a.header_line < b.header_line end)

  -- Send using new shooter.tmux module (includes history saving)
  local bufnr = vim.api.nvim_get_current_buf()
  require('shooter.tmux').send_specific_shots(pane_num, shot_infos, bufnr)
end

-- Helper: Refresh file picker
local function refresh_picker(pb)
  action_state.get_current_picker(pb):refresh(finders.new_table({
    results = get_prompt_files(),
    entry_maker = function(e)
      return {value = e, display = e.display, ordinal = e.display, path = e.path}
    end,
  }), {})
end

-- Edit file action
function M.edit_file(pb)
  local s = action_state.get_selected_entry()
  actions.close(pb)
  if s and s.path then vim.cmd('edit ' .. s.path) end
end

-- Delete file action
function M.delete_file(pb)
  local s = action_state.get_selected_entry()
  if not s then return end
  if vim.fn.input('Delete ' .. s.display .. '? (y/n): '):lower() == 'y' then
    os.remove(s.path)
    utils.echo('Deleted: ' .. s.display)
    refresh_picker(pb)
  end
  vim.cmd('redraw')
end

-- Delete shot action (for open shots picker)
function M.delete_shot(pb, target_file, refresh_fn)
  local entry = action_state.get_selected_entry()
  if not entry or not entry.value then
    utils.echo('No shot selected')
    return
  end

  local shot_data = entry.value
  local shot_num = shot_data.shot_num or '?'

  -- Confirm deletion
  if vim.fn.input('Delete shot ' .. shot_num .. '? (y/n): '):lower() ~= 'y' then
    vim.cmd('redraw')
    return
  end

  -- Get buffer for the file (load if necessary)
  local bufnr = vim.fn.bufnr(shot_data.target_file)
  local was_loaded = bufnr ~= -1

  if not was_loaded then
    bufnr = vim.fn.bufadd(shot_data.target_file)
    vim.fn.bufload(bufnr)
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local header_line = shot_data.header_line

  -- Find shot end (next shot header or end of file)
  local shot_end = #lines
  for i = header_line + 1, #lines do
    if lines[i]:match('^##%s+x?%s*shot') then
      shot_end = i - 1
      break
    end
  end

  -- Find shot start (include preceding blank line if exists)
  local shot_start = header_line
  if header_line > 1 and lines[header_line - 1]:match('^%s*$') then
    shot_start = header_line - 1
  end

  -- Delete the range
  vim.api.nvim_buf_set_lines(bufnr, shot_start - 1, shot_end, false, {})

  -- Save the file
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd('silent write')
  end)

  utils.echo('Deleted shot ' .. shot_num)
  vim.cmd('redraw')

  -- Refresh the picker
  if refresh_fn then
    refresh_fn(pb)
  end
end

-- Move file action
function M.move_file(pb, tfolder)
  local s = action_state.get_selected_entry()
  if not s then return end
  local cwd, src = vim.fn.getcwd(), s.path
  local fname = vim.fn.fnamemodify(src, ':t')
  local tdir = tfolder == '' and cwd .. '/plans/prompts' or cwd .. '/plans/prompts/' .. tfolder
  local tpath = tdir .. '/' .. fname
  local dname = tfolder == '' and 'prompts' or tfolder

  vim.fn.mkdir(tdir, 'p')
  if tfolder == '' and vim.fn.fnamemodify(src, ':h') == cwd .. '/plans/prompts' then
    utils.echo('Already in prompts')
    return
  elseif src:find('/' .. tfolder .. '/', 1, true) then
    utils.echo('Already in ' .. tfolder)
    return
  end
  if vim.fn.filereadable(tpath) == 1 then
    utils.echo('Target exists')
    return
  end

  if os.rename(src, tpath) then
    utils.echo('Moved to ' .. dname .. '/' .. fname)
    refresh_picker(pb)
  else
    utils.echo('Failed to move')
  end
  vim.cmd('redraw')
end

return M
