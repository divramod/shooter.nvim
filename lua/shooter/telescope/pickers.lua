-- Telescope pickers for shooter.nvim
local M = {}

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')

local utils = require('shooter.utils')
local config = require('shooter.config')
local files = require('shooter.core.files')
local shots = require('shooter.core.shots')
local previewers_mod = require('shooter.telescope.previewers')
local telescope_actions = require('shooter.telescope.actions')

-- Get files for telescope picker (returns display paths without plans/prompts prefix)
local function get_prompt_files()
  local cwd = vim.fn.getcwd()
  local prompts_dir = cwd .. '/plans/prompts'
  local file_list = vim.fn.globpath(prompts_dir, '**/*.md', false, true)
  local results = {}
  for _, file in ipairs(file_list) do
    -- Store both display path (without plans/prompts/) and full path
    local display = file:gsub('^' .. vim.pesc(prompts_dir) .. '/', '')
    table.insert(results, { display = display, path = file })
  end
  return results
end

-- List all next-action files
function M.list_all_files(opts)
  opts = opts or {}
  local cwd = vim.fn.getcwd()
  local prompts_dir = cwd .. '/plans/prompts'

  -- Ensure prompts directory exists
  vim.fn.mkdir(prompts_dir, 'p')

  local file_list = get_prompt_files()

  if #file_list == 0 then
    utils.echo('No prompt files found')
    return
  end

  return pickers.new(opts, {
    prompt_title = 'Next Actions (a/b/d/p/r/t/w=move, dd=delete)',
    layout_strategy = 'horizontal',
    layout_config = {
      width = 0.95,
      preview_width = 0.5,
    },
    finder = finders.new_table({
      results = file_list,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.display,
          path = entry.path,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers_mod.file_previewer(),
  })
end

-- Helper: Get target file (current or last edited)
local function get_target_file()
  local cwd = vim.fn.getcwd()
  local prompts_path = cwd .. '/plans/prompts'
  local filepath = vim.fn.expand('%:p')

  if filepath:find(prompts_path, 1, true) then
    return filepath, true
  end

  if vim.fn.isdirectory(prompts_path) ~= 1 then return nil, false end
  local handle = io.popen('find "' .. prompts_path .. '" -name "*.md" -type f -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1')
  if not handle then return nil, false end
  local last_file = handle:read('*l')
  handle:close()
  return last_file and last_file ~= '' and last_file or nil, false
end

-- Helper: Read file lines
local function read_lines(target_file, is_current)
  if is_current then
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end
  local file = io.open(target_file, 'r')
  if not file then return nil end
  local content = file:read('*a')
  file:close()
  local lines = {}
  for line in content:gmatch('[^\n]*') do
    table.insert(lines, line)
  end
  return lines
end

-- Helper: Find open shots
local function find_open_shots(lines)
  local shots = {}
  local i = 1
  while i <= #lines do
    if lines[i]:match('^##%s+shot') and not lines[i]:match('^##%s+x%s+shot') then
      local start_line = i
      local end_line = #lines
      for j = start_line + 1, #lines do
        if lines[j]:match('^##%s+x?%s*shot') then
          end_line = j - 1
          break
        end
      end
      while end_line > start_line and lines[end_line]:match('^%s*$') do
        end_line = end_line - 1
      end
      table.insert(shots, {start_line = start_line, end_line = end_line, header_line = start_line})
      i = end_line + 1
    else
      i = i + 1
    end
  end
  return shots
end

-- Helper: Create shot entry
local function make_shot_entry(shot, lines, target_file, is_current)
  local header = lines[shot.header_line]
  local shot_num = header:match('shot%s+(%d+)') or '?'
  local preview_lines = {}
  for idx = shot.start_line + 1, math.min(shot.start_line + 5, shot.end_line) do
    if lines[idx] and lines[idx] ~= '' then
      table.insert(preview_lines, lines[idx])
      if #preview_lines >= 3 then break end
    end
  end
  local preview = table.concat(preview_lines, ' | ')
  if #preview > 60 then preview = preview:sub(1, 60) .. '...' end
  return {
    shot_num = shot_num, header_line = shot.header_line,
    start_line = shot.start_line, end_line = shot.end_line,
    display = string.format('Shot %s: %s', shot_num, preview),
    lines = lines, target_file = target_file, is_current_file = is_current,
  }
end

-- List open shots in current or last edited file
function M.list_open_shots(opts)
  opts = opts or {}
  local target_file, is_current = get_target_file()
  if not target_file then utils.echo('No next-action files found'); return end

  local lines = read_lines(target_file, is_current)
  if not lines then utils.echo('Failed to read file'); return end

  local shot_list = find_open_shots(lines)
  if #shot_list == 0 then
    utils.echo('No open shots found')
    return
  end

  local shot_entries = {}
  for _, shot in ipairs(shot_list) do
    table.insert(shot_entries, make_shot_entry(shot, lines, target_file, is_current))
  end

  local filename = vim.fn.fnamemodify(target_file, ':t')
  local title = is_current and 'Open Shots (Tab=select, 1-4=send, Enter=jump)'
    or 'Open Shots from ' .. filename .. ' (Tab=select, 1-4=send, Enter=open)'

  return pickers.new(opts, {
    prompt_title = title,
    layout_strategy = 'vertical',
    layout_config = {width = 0.9, height = 0.9, preview_height = 0.5},
    initial_mode = 'normal',  -- Start in normal mode to quickly send shots with 1-4
    finder = finders.new_table({
      results = shot_entries,
      entry_maker = function(e) return {value = e, display = e.display, ordinal = e.display} end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers_mod.shot_previewer(),
    attach_mappings = function(prompt_bufnr, map)
      -- Enter opens the file at shot position
      actions.select_default:replace(function()
        local entry = require('telescope.actions.state').get_selected_entry()
        actions.close(prompt_bufnr)
        if entry and entry.value then
          local shot_data = entry.value
          if not shot_data.is_current_file then
            vim.cmd('edit ' .. vim.fn.fnameescape(shot_data.target_file))
          end
          vim.api.nvim_win_set_cursor(0, {shot_data.header_line, 0})
        end
      end)

      -- Send shot to pane 1-4
      for i = 1, 4 do
        map('n', tostring(i), function()
          telescope_actions.send_multiple_shots(prompt_bufnr, i)
        end)
      end

      -- Navigation with Ctrl-n/p in normal mode
      map('n', '<C-n>', actions.move_selection_next)
      map('n', '<C-p>', actions.move_selection_previous)

      -- Close with Ctrl-c in normal mode
      map('n', '<C-c>', actions.close)

      return true
    end,
  })
end

return M
