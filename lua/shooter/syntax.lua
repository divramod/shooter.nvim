-- Syntax highlighting for shooter.nvim
-- Highlights shot headers in prompt files

local M = {}

-- Define highlight groups from config
local function define_highlights()
  local config = require('shooter.config')
  local open_shot = config.get('highlight.open_shot') or {}
  local done_shot = config.get('highlight.done_shot') or {}

  -- Default: black text on light orange background (avoids search highlight confusion)
  vim.api.nvim_set_hl(0, 'ShooterOpenShot', {
    fg = open_shot.fg or '#000000',
    bg = open_shot.bg or '#ffb347',
    bold = open_shot.bold ~= false, -- default true
  })

  -- Light green for the single latest executed shot (most recent by timestamp)
  vim.api.nvim_set_hl(0, 'ShooterDoneShot', {
    fg = done_shot.fg or '#555555',
    bg = done_shot.bg or '#c8e6c9',
    bold = done_shot.bold or false,
  })

  -- Light brown for the first executed shot of each day (day separator)
  local day_marker = config.get('highlight.day_marker') or {}
  vim.api.nvim_set_hl(0, 'ShooterDayMarker', {
    fg = day_marker.fg or '#555555',
    bg = day_marker.bg or '#e6d5b8',
    bold = day_marker.bold or false,
  })
end

-- Check if a line is a fenced code block delimiter (not inline code)
-- Fenced code block: starts with ``` and does NOT have closing ``` on same line
local function is_fence_delimiter(line)
  if not line:match('^%s*```') then return false end
  local _, count = line:gsub('```', '')
  return count == 1  -- Only one ``` sequence = fence delimiter
end

-- Check if a line number is inside a code block
local function is_in_code_block(bufnr, line_num)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, line_num, false)
  local in_block = false
  for _, line in ipairs(lines) do
    if is_fence_delimiter(line) then
      in_block = not in_block
    end
  end
  return in_block
end

-- Apply syntax highlighting to current buffer
local function apply_syntax(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  pcall(vim.fn.clearmatches)

  local config = require('shooter.config')
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Find the single latest executed shot by timestamp (regardless of @shot- ref)
  local latest_done_line = nil
  local latest_timestamp = nil
  local exec_pattern = config.get('patterns.executed_shot_header')
  for i, line in ipairs(lines) do
    if line:match(exec_pattern) then
      local ts = line:match('%((%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)%)')
      if ts and (not latest_timestamp or ts > latest_timestamp) then
        latest_timestamp = ts
        latest_done_line = i
      end
    end
  end

  -- Find the first executed shot of each day (day markers for navigation)
  local day_first_lines = {}
  local seen_days = {}
  for i, line in ipairs(lines) do
    if line:match(exec_pattern) and not is_in_code_block(bufnr, i) then
      local date = line:match('%((%d%d%d%d%-%d%d%-%d%d)%s+%d%d:%d%d:%d%d%)')
      if date and not seen_days[date] then
        seen_days[date] = true
        day_first_lines[i] = true
      end
    end
  end

  -- Highlight: open shots (orange), latest executed (green), day markers (light brown)
  for i, line in ipairs(lines) do
    if not is_in_code_block(bufnr, i) then
      if i == latest_done_line then
        vim.fn.matchaddpos('ShooterDoneShot', { { i } }, 10)
      elseif day_first_lines[i] then
        vim.fn.matchaddpos('ShooterDayMarker', { { i } }, 5)
      elseif line:match('^##%s+shot%s+[%d%?]+') then
        vim.fn.matchaddpos('ShooterOpenShot', { { i } }, -1)
      end
    end
  end
end

-- Check if file is a prompts file (not Oil buffer, must be actual .md file in .shooter/project-shotfiles)
local function is_prompts_file(filepath)
  -- Exclude Oil buffers
  if filepath:match('^oil://') then return false end
  -- Must be a .md file in .shooter/project-shotfiles folder (including subdirectories like backlog/, archive/, etc.)
  return filepath:match('.shooter/project%-shotfiles/.+%.md$') ~= nil
end

-- Track which buffers already showed the open notification
local notified_bufs = {}

-- Show shotfile info notification (repo, filename, open/total shots)
local function show_shotfile_info(bufnr)
  if notified_bufs[bufnr] then return end
  notified_bufs[bufnr] = true

  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    local shots = require('shooter.core.shots')
    local all = shots.find_all_shots(bufnr)
    local open = shots.find_open_shots(bufnr)

    local filepath = vim.api.nvim_buf_get_name(bufnr)
    local filename = vim.fn.fnamemodify(filepath, ':t:r')

    -- Get repo name from git root folder
    local git_root = vim.fn.systemlist('git rev-parse --show-toplevel 2>/dev/null')
    local repo = (vim.v.shell_error == 0 and #git_root > 0)
      and vim.fn.fnamemodify(git_root[1], ':t') or ''

    local msg = string.format('%s/%s  %d/%d shots open', repo, filename, #open, #all)
    vim.notify(msg, vim.log.levels.INFO, { timeout = 3000 })
  end)
end

-- Setup autocommands for syntax highlighting
function M.setup()
  define_highlights()

  local group = vim.api.nvim_create_augroup('ShooterSyntax', { clear = true })

  -- Apply highlighting when entering prompts files
  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
    group = group,
    pattern = '*.md',
    callback = function(ev)
      local filepath = vim.api.nvim_buf_get_name(ev.buf)
      local ft = vim.bo[ev.buf].filetype
      -- Only apply to markdown files in .shooter/project-shotfiles (not oil, not other filetypes)
      if ft == 'markdown' and is_prompts_file(filepath) then
        apply_syntax(ev.buf)
        show_shotfile_info(ev.buf)
      else
        pcall(vim.fn.clearmatches)
      end
    end,
  })

  -- Clear matches when entering ANY non-prompts buffer (catches Oil, etc.)
  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
    group = group,
    callback = function(ev)
      local filepath = vim.api.nvim_buf_get_name(ev.buf)
      -- If not a prompts file, clear window matches
      if not is_prompts_file(filepath) then
        pcall(vim.fn.clearmatches)
      end
    end,
  })

  -- Reapply when text changes (to handle code block additions/removals)
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = group,
    pattern = '*.md',
    callback = function(ev)
      local filepath = vim.api.nvim_buf_get_name(ev.buf)
      local ft = vim.bo[ev.buf].filetype
      if ft == 'markdown' and is_prompts_file(filepath) then
        apply_syntax(ev.buf)
      end
    end,
  })

  -- Clear notification tracking when buffer is deleted
  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    callback = function(ev)
      notified_bufs[ev.buf] = nil
    end,
  })

  -- Reapply on colorscheme change
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,
    callback = function()
      define_highlights()
    end,
  })
end

return M
