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

-- Build code block map in a single O(n) pass
-- Returns a table where map[line_num] = true if that line is inside a code block
local function build_code_block_map(lines)
  local in_block = false
  local map = {}
  for i, line in ipairs(lines) do
    if is_fence_delimiter(line) then
      in_block = not in_block
    end
    if in_block then
      map[i] = true
    end
  end
  return map
end

-- Day marker coloring toggle (enabled by default, O(n) performance is fine)
local day_marker_enabled = true

-- Forward declaration
local apply_syntax

-- Apply syntax highlighting to current buffer
apply_syntax = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  pcall(vim.fn.clearmatches)

  local config = require('shooter.config')
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Single O(n) pass: build code block map
  local in_code = build_code_block_map(lines)

  -- Find the single latest executed shot by timestamp
  local latest_done_line = nil
  local latest_timestamp = nil
  local exec_pattern = config.get('patterns.executed_shot_header')

  -- Find day markers (only if enabled) — done in same loop for efficiency
  local day_first_lines = {}
  local seen_days = {}

  for i, line in ipairs(lines) do
    if not in_code[i] and line:match(exec_pattern) then
      local ts = line:match('%((%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)%)')
      if ts and (not latest_timestamp or ts > latest_timestamp) then
        latest_timestamp = ts
        latest_done_line = i
      end
      if day_marker_enabled then
        local date = line:match('%((%d%d%d%d%-%d%d%-%d%d)%s+%d%d:%d%d:%d%d%)')
        if date then
          seen_days[date] = i  -- keep overwriting; last occurrence = earliest shot of the day
        end
      end
    end
  end

  -- Convert seen_days map (date -> line) to day_first_lines set (line -> true)
  for _, line_num in pairs(seen_days) do
    day_first_lines[line_num] = true
  end

  -- Highlight: open shots (orange), latest executed (green), day markers (light brown)
  for i, line in ipairs(lines) do
    if not in_code[i] then
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

-- Check if file is a prompts file (not Oil buffer, must be actual .md file in .shooter/shotfiles)
local function is_prompts_file(filepath)
  -- Exclude Oil buffers
  if filepath:match('^oil://') then return false end
  -- Must be a .md file in .shooter/shotfiles folder (including subdirectories like backlog/, archive/, etc.)
  return filepath:match('.shooter/shotfiles/.+%.md$') ~= nil
end

-- Toggle day marker coloring on/off
function M.toggle_day_marker()
  day_marker_enabled = not day_marker_enabled
  local status = day_marker_enabled and 'enabled' or 'disabled'
  vim.notify('Day marker coloring: ' .. status, vim.log.levels.INFO)
  -- Reapply syntax immediately
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if is_prompts_file(filepath) then
    apply_syntax(bufnr)
  end
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
      -- Only apply to markdown files in .shooter/shotfiles (not oil, not other filetypes)
      if ft == 'markdown' and is_prompts_file(filepath) then
        require('shooter.core.files').track_last_shotfile(filepath)
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

  -- Reapply when text changes (debounced to avoid lag while typing)
  local pending_syntax = {}
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = group,
    pattern = '*.md',
    callback = function(ev)
      local filepath = vim.api.nvim_buf_get_name(ev.buf)
      local ft = vim.bo[ev.buf].filetype
      if ft == 'markdown' and is_prompts_file(filepath) then
        if pending_syntax[ev.buf] then return end
        pending_syntax[ev.buf] = true
        local debounce = 500
        local eok, ext_config = pcall(require, 'shooter.core.ext_config')
        if eok then debounce = ext_config.get('file.first_shot_of_the_day.debounce_in_ms') or debounce end
        vim.defer_fn(function()
          pending_syntax[ev.buf] = nil
          if vim.api.nvim_buf_is_valid(ev.buf) then
            apply_syntax(ev.buf)
          end
        end, debounce)
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

  -- Auto-reload config and reapply syntax when config.yaml is saved
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    pattern = 'config.yaml',
    callback = function(ev)
      local filepath = vim.api.nvim_buf_get_name(ev.buf)
      -- Only react to shooter config files (global or project-local)
      if filepath:match('shooter/nvim/config%.yaml$') or filepath:match('%.shooter/cfg/nvim/config%.yaml$') then
        local ext_config = require('shooter.core.ext_config')
        ext_config.reload()
        define_highlights()
        M.reapply_all()
        vim.notify('Shooter config reloaded', vim.log.levels.INFO)
      end
    end,
  })

  -- Auto-fix config.yaml on BufEnter: strip invalid keys, fill missing defaults (global)
  -- Runs once per buffer (tracked by fixed_cfg_bufs) to avoid repeated fixes.
  -- Updates buffer lines directly (no disk write) to avoid W12 warnings.
  local fixed_cfg_bufs = {}
  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    pattern = 'config.yaml',
    callback = function(ev)
      if fixed_cfg_bufs[ev.buf] then return end
      local filepath = vim.api.nvim_buf_get_name(ev.buf)
      local is_global = filepath:match('shooter/nvim/config%.yaml$') and not filepath:match('%.shooter/cfg/nvim/config%.yaml$')
      local is_local = filepath:match('%.shooter/cfg/nvim/config%.yaml$')
      if not is_global and not is_local then return end
      fixed_cfg_bufs[ev.buf] = true
      local eok, ext_config = pcall(require, 'shooter.core.ext_config')
      if not eok then return end
      local removed, added = ext_config.fix_config_buffer(ev.buf, is_global)
      if removed > 0 or added > 0 then
        local parts = {}
        if removed > 0 then table.insert(parts, 'removed ' .. removed .. ' invalid') end
        if added > 0 then table.insert(parts, 'added ' .. added .. ' missing') end
        vim.notify('Config auto-fixed: ' .. table.concat(parts, ', '), vim.log.levels.INFO)
      end
    end,
  })

  -- Clear fixed_cfg_bufs tracking when buffer is deleted
  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    pattern = 'config.yaml',
    callback = function(ev)
      fixed_cfg_bufs[ev.buf] = nil
    end,
  })
end

-- Reapply syntax highlighting to all loaded shotfile buffers
-- Also applies ext_config YAML overrides for all highlight groups
function M.reapply_all()
  define_highlights()
  -- Apply ext_config color overrides on top of defaults
  local eok, ext_config = pcall(require, 'shooter.core.ext_config')
  if eok then
    -- Day marker (first shot of the day)
    local day_bg = ext_config.get('file.first_shot_of_the_day.color_bg')
    local day_fg = ext_config.get('file.first_shot_of_the_day.color_fg')
    if type(day_bg) == 'string' or type(day_fg) == 'string' then
      local config = require('shooter.config')
      local day_marker = config.get('highlight.day_marker') or {}
      vim.api.nvim_set_hl(0, 'ShooterDayMarker', {
        fg = day_fg or day_marker.fg or '#555555',
        bg = day_bg or day_marker.bg or '#e6d5b8',
        bold = day_marker.bold or false,
      })
    end
    -- Open shots
    local open_bg = ext_config.get('file.open_shots.color_bg')
    local open_fg = ext_config.get('file.open_shots.color_fg')
    if type(open_bg) == 'string' or type(open_fg) == 'string' then
      local config = require('shooter.config')
      local open_shot = config.get('highlight.open_shot') or {}
      vim.api.nvim_set_hl(0, 'ShooterOpenShot', {
        fg = open_fg or open_shot.fg or '#000000',
        bg = open_bg or open_shot.bg or '#ffb347',
        bold = open_shot.bold ~= false,
      })
    end
    -- Closed shots (latest executed)
    local closed_bg = ext_config.get('file.closed_shots.color_bg')
    local closed_fg = ext_config.get('file.closed_shots.color_fg')
    if type(closed_bg) == 'string' or type(closed_fg) == 'string' then
      local config = require('shooter.config')
      local done_shot = config.get('highlight.done_shot') or {}
      vim.api.nvim_set_hl(0, 'ShooterDoneShot', {
        fg = closed_fg or done_shot.fg or '#555555',
        bg = closed_bg or done_shot.bg or '#c8e6c9',
        bold = done_shot.bold or false,
      })
    end
  end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local filepath = vim.api.nvim_buf_get_name(bufnr)
      if is_prompts_file(filepath) then
        apply_syntax(bufnr)
      end
    end
  end
end

return M
