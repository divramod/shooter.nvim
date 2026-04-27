-- Shot creation entry points.

local utils = require('shooter.utils')
local shots = require('shooter.core.shots')
local insertion = require('shooter.core.shot_actions.insertion')

local M = {}

local function find_insertion_line(bufnr)
  return insertion.find_insertion_line(bufnr)
end

-- Create a new shot at the top (below title, above other shots).
function M.create_new_shot()
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

  local header_offset = needs_blank_before and 1 or 0
  vim.api.nvim_win_set_cursor(0, { insert_line + header_offset, 0 })
  vim.cmd('startinsert!')
  utils.echo('Created shot ' .. next_num)
end

-- Create new shot and start whisper for dictation.
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

-- Create a shot from text stored in a file (called via tmux send-keys from another pane).
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

  local cursor_line = insert_line + (needs_blank_before and 2 or 1)
  vim.api.nvim_win_set_cursor(0, { cursor_line, 0 })

  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname ~= '' then
    vim.cmd('silent! write')
  end

  os.remove(filepath)

  utils.echo('Created shot ' .. next_num .. ' from Claude')
end

-- Self-contained luafile script that creates a shot from a temp file. Used by
-- create_shot_from_claude so the target Neovim doesn't need shooter loaded.
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

local title_line = nil
for i, line in ipairs(lines) do
  if line:match("^#%%s+[^#]") then title_line = i; break end
end

local first_shot = nil
if title_line then
  for i = title_line + 1, #lines do
    if lines[i]:match("^##%%s+x?%%s*shot") then first_shot = i; break end
  end
end

local max_shot = 0
for _, line in ipairs(lines) do
  local num = line:match("^##%%s+x?%%s*shot%%s+(%%d+)")
  if num then local n = tonumber(num); if n > max_shot then max_shot = n end end
end
local next_num = max_shot + 1

local insert_line = (title_line or 0) + 1
if first_shot then insert_line = first_shot end

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

-- Cut text from Claude's ctrl+g editor buffer, close it, and create a shot in the right tmux pane.
function M.create_shot_from_claude()
  local lines = utils.get_buf_lines(0, 0, -1)
  local text = table.concat(lines, '\n')
  text = utils.trim(text)

  if text == '' then
    utils.echo('Buffer is empty, nothing to send')
    return
  end

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

  local right_pane = vim.fn.system('tmux display-message -p -t "{right}" "#{pane_id}"')
  right_pane = vim.trim(right_pane)

  if right_pane == '' or right_pane:match('can.t') or right_pane:match('error') then
    utils.echo('No right pane found')
    os.remove(tmp_file)
    os.remove(script_file)
    return
  end

  vim.fn.system('tmux send-keys -t ' .. right_pane .. ' Escape')
  vim.fn.system(
    'tmux send-keys -t ' .. right_pane
    .. ' ":luafile ' .. script_file .. '" Enter'
  )

  vim.api.nvim_buf_set_lines(0, 0, -1, false, {})

  vim.fn.system('tmux select-pane -t ' .. right_pane)

  vim.cmd('wq')
end

return M
