-- Telescope action handlers for shooter.nvim
local M = {}

local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local finders = require('telescope.finders')

local utils = require('shooter.utils')
local config = require('shooter.config')

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

-- Send shot to claude pane
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

  -- Send to claude using existing command
  vim.cmd('DmNextActionSend' .. (pane_num == 1 and '' or tostring(pane_num)))
end

-- Helper: Read file safely
local function read_safe(path)
  local f = io.open(path, 'r')
  if not f then return "(Could not read: " .. path .. ")" end
  local c = f:read('*a')
  f:close()
  return c
end

-- Helper: Build multishot message
local function build_multishot_message(selected_shots, lines, target_file)
  local shot_parts, shot_nums = {}, {}
  for _, shot in ipairs(selected_shots) do
    local num = lines[shot.header_line]:match('shot%s+(%d+)') or '?'
    local clines = {}
    for i = shot.start_line + 1, shot.end_line do
      if lines[i] then table.insert(clines, lines[i]) end
    end
    while #clines > 0 and clines[1]:match('^%s*$') do table.remove(clines, 1) end
    table.insert(shot_nums, num)
    table.insert(shot_parts, string.format("## shot %s\n%s", num, table.concat(clines, '\n')))
  end

  local shots_str = table.concat(shot_nums, ", ")
  local title = lines[1] and lines[1]:match('^#%s+(.+)$') or vim.fn.fnamemodify(target_file, ':t:r')
  local gen = vim.fn.expand('~/dev/.ai/na-context-general.md')
  local proj = vim.fn.expand(vim.fn.getcwd() .. '/.ai/na-context.md')

  return string.format([[# shots %s (%s)
%s

# context
1. shots %s of "%s". 2. read %s for context. 3. implement all, best order. 4. commit each per repo conventions.

# General (%s)
%s

# Project (%s)
%s]], shots_str, title, table.concat(shot_parts, "\n\n"), shots_str, title, target_file, gen, read_safe(gen), proj, read_safe(proj))
end

-- Helper: Send to tmux pane
local function send_to_pane(message, pane_num, shot_count)
  local tmp = os.tmpname()
  local f = io.open(tmp, "w")
  if not f then utils.echo("Failed to create temp"); return false end
  f:write(message); f:close()

  local h = io.popen(string.format("tmux list-panes -F '#{pane_id}:#{pane_tty}' 2>/dev/null | head -%d | tail -1 | cut -d: -f1", pane_num))
  local pid = h and h:read("*l") or nil
  if h then h:close() end

  if not pid or pid == '' then utils.echo("No pane #" .. pane_num); os.remove(tmp); return false end

  local cmd = string.format("tmux send-keys -t %s Escape Escape i && sleep 0.1 && tmux load-buffer %s && tmux paste-buffer -t %s && sleep 2.0 && tmux send-keys -t %s Enter && sleep 0.1 && tmux send-keys -t %s Enter && rm %s",
    pid, tmp, pid, pid, pid, tmp)

  if os.execute(cmd) == 0 then
    local pmsg = pane_num == 1 and "" or string.format(" #%d", pane_num)
    utils.echo(string.format("Sent %d shot%s to claude%s (%d chars)", shot_count, shot_count > 1 and "s" or "", pmsg, #message))
    return true
  else
    utils.echo("Failed to send"); os.remove(tmp); return false
  end
end

-- Send multiple shots to claude pane
function M.send_multiple_shots(prompt_bufnr, pane_num)
  pane_num = pane_num or 1
  local multi = action_state.get_current_picker(prompt_bufnr):get_multi_selection()
  if #multi <= 1 then M.send_shot(prompt_bufnr, pane_num); return end

  actions.close(prompt_bufnr)
  local first = multi[1].value
  if not first.is_current_file then vim.cmd('edit ' .. vim.fn.fnameescape(first.target_file)) end

  local sel = {}
  for _, e in ipairs(multi) do
    table.insert(sel, {start_line = e.value.start_line, end_line = e.value.end_line, header_line = e.value.header_line})
  end
  table.sort(sel, function(a, b) return a.header_line < b.header_line end)

  if send_to_pane(build_multishot_message(sel, first.lines, first.target_file), pane_num, #sel) then
    local ts = require('functions.tmux-send')
    for _, shot in ipairs(sel) do ts.mark_shot_executed(shot.header_line) end
  end
end

-- Helper: Refresh file picker
local function refresh_picker(pb)
  action_state.get_current_picker(pb):refresh(finders.new_table({
    results = get_prompt_files(),
    entry_maker = function(e) return {value = e, display = e.display, ordinal = e.display, path = e.path} end,
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
    os.remove(s.path); utils.echo('Deleted: ' .. s.display); refresh_picker(pb)
  end
  vim.cmd('redraw')
end

-- Move file action
function M.move_file(pb, tfolder)
  local s = action_state.get_selected_entry()
  if not s then return end
  local cwd, src = vim.fn.getcwd(), s.path
  local fname = vim.fn.fnamemodify(src, ':t')
  local tdir = tfolder == '' and cwd .. '/plans/prompts' or cwd .. '/plans/prompts/' .. tfolder
  local tpath, dname = tdir .. '/' .. fname, tfolder == '' and 'prompts' or tfolder

  vim.fn.mkdir(tdir, 'p')
  if tfolder == '' and vim.fn.fnamemodify(src, ':h') == cwd .. '/plans/prompts' then
    utils.echo('Already in prompts'); return
  elseif src:find('/' .. tfolder .. '/', 1, true) then
    utils.echo('Already in ' .. tfolder); return
  end
  if vim.fn.filereadable(tpath) == 1 then utils.echo('Target exists'); return end

  if os.rename(src, tpath) then
    utils.echo('Moved to ' .. dname .. '/' .. fname); refresh_picker(pb)
  else utils.echo('Failed to move') end
  vim.cmd('redraw')
end

return M
