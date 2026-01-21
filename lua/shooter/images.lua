-- Image insertion for shooter.nvim
-- Insert image references via hal image pick

local utils = require('shooter.utils')
local files = require('shooter.core.files')
local config = require('shooter.config')

local M = {}

-- Insert images into current shooter file
function M.insert_images()
  local filepath = vim.fn.expand('%:p')
  local prompts_dir = files.get_prompts_dir()

  -- Check if we're in a shooter file
  if not filepath:find(prompts_dir, 1, true) then
    utils.echo('Not in a shooter file')
    return
  end

  -- Check if we're in tmux
  if not utils.in_tmux() then
    utils.echo('Image picker requires tmux')
    return
  end

  -- Save cursor position
  local saved_cursor = vim.api.nvim_win_get_cursor(0)

  -- Save buffer before opening picker
  vim.cmd('write')

  local tmpfile = '/tmp/nvim-hal-image-pick.txt'

  -- Clear previous output
  os.remove(tmpfile)

  -- Run image picker in maximized tmux split pane
  local wait_channel = 'nvim-image-pick-' .. vim.fn.getpid()
  vim.fn.system('tmux split-window -h -Z "hal image pick --output ' .. tmpfile .. ' ; tmux wait-for -S ' .. wait_channel .. '"')
  vim.fn.system('tmux wait-for ' .. wait_channel)

  -- Read selected images
  local file = io.open(tmpfile, 'r')
  if not file then
    utils.echo('No images selected')
    return
  end

  local images = {}
  for line in file:lines() do
    if line ~= '' and line:match('^/') then
      table.insert(images, line)
    end
  end
  file:close()
  os.remove(tmpfile)

  if #images == 0 then
    utils.echo('No images selected')
    return
  end

  -- Find existing image count
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local max_img = 0
  for _, line in ipairs(lines) do
    local img_num = line:match('^img(%d+):')
    if img_num then
      local num = tonumber(img_num)
      if num and num > max_img then
        max_img = num
      end
    end
  end

  -- Find current shot boundaries
  local total_lines = #lines
  local cursor_row = saved_cursor[1]

  -- Find next shot header after cursor (or EOF)
  local next_shot_line = total_lines + 1
  for i = cursor_row + 1, total_lines do
    if lines[i]:match(config.get('patterns.shot_header')) then
      next_shot_line = i
      break
    end
  end

  -- Find existing images in current shot
  local last_img_line = nil
  for i = cursor_row, next_shot_line - 1 do
    if lines[i]:match('^img%d+:') then
      last_img_line = i
    end
  end

  -- Build new image lines
  local new_img_lines = {}
  for i, img_path in ipairs(images) do
    local img_num = max_img + i
    table.insert(new_img_lines, string.format('img%d: %s', img_num, img_path))
  end

  if last_img_line then
    -- Append after last existing image
    vim.api.nvim_buf_set_lines(0, last_img_line, last_img_line, false, new_img_lines)
  else
    -- Insert before next shot header
    local insert_at = next_shot_line - 1
    while insert_at > cursor_row and lines[insert_at]:match('^%s*$') do
      insert_at = insert_at - 1
    end
    local to_insert = { '' }
    for _, line in ipairs(new_img_lines) do
      table.insert(to_insert, line)
    end
    vim.api.nvim_buf_set_lines(0, insert_at, insert_at, false, to_insert)
  end

  -- Ensure one blank line between images and next shot
  lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  total_lines = #lines
  for i = cursor_row + 1, total_lines do
    if lines[i]:match(config.get('patterns.shot_header')) then
      local blank_count = 0
      local j = i - 1
      while j > 0 and lines[j]:match('^%s*$') do
        blank_count = blank_count + 1
        j = j - 1
      end
      if blank_count > 1 then
        vim.api.nvim_buf_set_lines(0, j + 1, i - 1, false, { '' })
      elseif blank_count == 0 then
        vim.api.nvim_buf_set_lines(0, i - 1, i - 1, false, { '' })
      end
      break
    end
  end

  -- Restore cursor and save
  vim.api.nvim_win_set_cursor(0, saved_cursor)
  vim.cmd('write')

  local msg = #images == 1 and '1 image reference added' or (#images .. ' image references added')
  utils.echo(msg)
end

return M
