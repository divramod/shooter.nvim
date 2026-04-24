-- Syntax highlighting for shooter.nvim
-- Highlights shot headers in prompt files

local M = {}

-- Define highlight groups from config
local function define_highlights()
  local config = require('shooter.config')
  local open_shot = config.get('highlight.open_shot') or {}
  local open_shot_title = config.get('highlight.open_shot_title') or {}
  local done_shot_prefix = config.get('highlight.done_shot_prefix') or {}
  local done_shot_title = config.get('highlight.done_shot_title') or {}
  local done_shot_postfix = config.get('highlight.done_shot_postfix') or {}
  local day_marker_prefix = config.get('highlight.day_marker_prefix') or {}
  local day_marker_title = config.get('highlight.day_marker_title') or {}
  local day_marker_postfix = config.get('highlight.day_marker_postfix') or {}

  -- Default: black text on light orange background (avoids search highlight confusion)
  vim.api.nvim_set_hl(0, 'HalShooterOpenShot', {
    fg = open_shot.fg or '#000000',
    bg = open_shot.bg or '#ffb347',
    bold = open_shot.bold ~= false, -- default true
  })

  -- Open shot title: dark gray text on light yellow background
  vim.api.nvim_set_hl(0, 'HalShooterOpenShotTitle', {
    fg = open_shot_title.fg or '#333333',
    bg = open_shot_title.bg or '#ffe0a3',
    bold = open_shot_title.bold or false,
  })

  -- Done shot prefix (## x shot N): subtle, no background by default
  vim.api.nvim_set_hl(0, 'HalShooterDoneShotPrefix', {
    fg = done_shot_prefix.fg or '#888888',
    bg = done_shot_prefix.bg or nil,
    bold = done_shot_prefix.bold or false,
  })

  -- Done shot title: prominent green background so it stands out
  vim.api.nvim_set_hl(0, 'HalShooterDoneShotTitle', {
    fg = done_shot_title.fg or '#555555',
    bg = done_shot_title.bg or '#dcedc8',
    bold = done_shot_title.bold or false,
  })

  -- Done shot postfix (timestamp + ref): subtle, no background by default
  vim.api.nvim_set_hl(0, 'HalShooterDoneShotPostfix', {
    fg = done_shot_postfix.fg or '#888888',
    bg = done_shot_postfix.bg or nil,
    bold = done_shot_postfix.bold or false,
  })

  -- Day marker prefix (## x shot N): subtle, no background by default
  vim.api.nvim_set_hl(0, 'HalShooterDayMarkerPrefix', {
    fg = day_marker_prefix.fg or '#888888',
    bg = day_marker_prefix.bg or nil,
    bold = day_marker_prefix.bold or false,
  })

  -- Day marker title: prominent brown background so it stands out
  vim.api.nvim_set_hl(0, 'HalShooterDayMarkerTitle', {
    fg = day_marker_title.fg or '#555555',
    bg = day_marker_title.bg or '#f0e4d0',
    bold = day_marker_title.bold or false,
  })

  -- Day marker postfix (timestamp + ref): subtle, no background by default
  vim.api.nvim_set_hl(0, 'HalShooterDayMarkerPostfix', {
    fg = day_marker_postfix.fg or '#888888',
    bg = day_marker_postfix.bg or nil,
    bold = day_marker_postfix.bold or false,
  })

  -- Markdown links and file paths: blue underlined link look.
  vim.api.nvim_set_hl(0, 'HalShooterMdLink', {
    fg = '#4fa3ff',
    underline = true,
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

-- Extmark namespace — buffer-local highlights that move with text (no flicker)
local ns = vim.api.nvim_create_namespace('shooter_syntax')

-- Split an executed shot header into number/title/metadata column ranges.
-- Format: "## x shot N <title> (timestamp) @ref"
-- Returns number_end (col after "## x shot N"), title_start, title_end (before metadata)
-- title_start/title_end are nil when there is no title.
local function split_executed_header(line)
  local _, number_end_pos = line:find('^##%s+x%s+shot%s+[%d%?]+')
  if not number_end_pos then return nil end
  -- Find the timestamp marker "(YYYY-..."
  local meta_start = line:find('%s+%(%d%d%d%d%-')
  if not meta_start then
    -- No timestamp found — treat rest as title
    local title_start = line:find('%S', number_end_pos + 1)
    if title_start then
      return number_end_pos, title_start, #line
    end
    return number_end_pos, nil, nil
  end
  -- Check for title between number and metadata
  local title_start = line:find('%S', number_end_pos + 1)
  if title_start and title_start < meta_start then
    -- Title ends just before the metadata space
    return number_end_pos, title_start, meta_start
  end
  return number_end_pos, nil, nil
end

-- Apply syntax highlighting to current buffer using extmarks
-- Extmarks are buffer-local and track buffer positions — they move with text
-- when lines are inserted/deleted, so highlights stay correct between redraws.
-- clear_namespace + set_extmark within a single callback is atomic (one redraw).
apply_syntax = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

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

  -- Build match list: { { line, group, col_start, col_end }, ... }
  -- col_start/col_end are optional; when nil, the full line is highlighted.
  local matches = {}
  for i, line in ipairs(lines) do
    if not in_code[i] then
      if i == latest_done_line or day_first_lines[i] then
        -- Executed shot: split into prefix, title, and postfix (3 independent zones)
        local prefix_group = i == latest_done_line and 'HalShooterDoneShotPrefix' or 'HalShooterDayMarkerPrefix'
        local title_group = i == latest_done_line and 'HalShooterDoneShotTitle' or 'HalShooterDayMarkerTitle'
        local postfix_group = i == latest_done_line and 'HalShooterDoneShotPostfix' or 'HalShooterDayMarkerPostfix'
        local number_end, title_start, title_end = split_executed_header(line)
        if number_end and title_start then
          -- Prefix portion: "## x shot N "
          table.insert(matches, { i, prefix_group, 0, title_start - 1 })
          -- Title portion: title text only
          table.insert(matches, { i, title_group, title_start - 1, title_end })
          -- Postfix portion: "(timestamp) @ref"
          table.insert(matches, { i, postfix_group, title_end, #line })
        else
          -- No title, highlight entire line with prefix color
          table.insert(matches, { i, prefix_group })
        end
      elseif line:match('^##%s+shot%s+[%d%?]+') then
        -- Split open shot header into number and title parts
        -- Number part: "## shot N" (or "## shot ?")
        local _, number_end_pos = line:find('^##%s+shot%s+[%d%?]+')
        -- Check if there's a title after the number (separated by space)
        local title_start = line:find('%S', number_end_pos + 1)
        if title_start then
          -- Number portion: from start to just before title (includes trailing space)
          table.insert(matches, { i, 'HalShooterOpenShot', 0, title_start - 1 })
          -- Title portion: from title start to end of line
          table.insert(matches, { i, 'HalShooterOpenShotTitle', title_start - 1, #line })
        else
          -- No title, highlight entire line as number
          table.insert(matches, { i, 'HalShooterOpenShot' })
        end
      else
        -- Highlight markdown links and file paths on non-shot lines.
        local md_links = require('shooter.markdown_links')
        for _, r in ipairs(md_links.find_ranges(line)) do
          table.insert(matches, { i, 'HalShooterMdLink', r[1], r[2] })
        end
      end
    end
  end

  -- Clear old extmarks and set new ones (atomic: single redraw, no flicker)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  for _, m in ipairs(matches) do
    if m[3] then
      -- Partial line highlight (col_start, col_end specified)
      vim.api.nvim_buf_set_extmark(bufnr, ns, m[1] - 1, m[3], {
        end_col = m[4],
        hl_group = m[2],
      })
    else
      -- Full line highlight
      vim.api.nvim_buf_set_extmark(bufnr, ns, m[1] - 1, 0, {
        end_col = #lines[m[1]],
        hl_group = m[2],
      })
    end
  end
end

-- Check if file is a prompts file (not Oil buffer, must be actual .md file in .hal/util/shooter/shotfiles)
local function is_prompts_file(filepath)
  -- Exclude Oil buffers
  if filepath:match('^oil://') then return false end
  -- Must be a .md file in .hal/util/shooter/shotfiles folder (including subdirectories like backlog/, archive/, etc.)
  return filepath:match('.hal/util/shooter/shotfiles/.+%.md$') ~= nil
end

-- Toggle day marker coloring on/off
function M.toggle_day_marker()
  day_marker_enabled = not day_marker_enabled
  local status = day_marker_enabled and 'enabled' or 'disabled'
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
-- Respects ext_config file.stats_notification.enabled (default true)
local function show_shotfile_info(bufnr)
  if notified_bufs[bufnr] then return end
  notified_bufs[bufnr] = true

  -- Check if stats notification is disabled via ext_config
  local eok, ext_config = pcall(require, 'shooter.core.ext_config')
  if eok then
    local enabled = ext_config.get('file.stats_notification.enabled')
    if enabled == false then return end
  end

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
  end)
end

-- Setup autocommands for syntax highlighting
function M.setup()
  define_highlights()

  local group = vim.api.nvim_create_augroup('HalShooterSyntax', { clear = true })

  -- Apply highlighting when entering prompts files; also track
  -- docs/plans/masterplan.md for < >l (last opened file) without applying
  -- shotfile syntax to it.
  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
    group = group,
    pattern = '*.md',
    callback = function(ev)
      local filepath = vim.api.nvim_buf_get_name(ev.buf)
      local ft = vim.bo[ev.buf].filetype
      if ft ~= 'markdown' then return end
      local files_mod = require('shooter.core.files')
      if is_prompts_file(filepath) then
        files_mod.track_last_shotfile(filepath)
        apply_syntax(ev.buf)
        show_shotfile_info(ev.buf)
        -- Enable autoread so checktime polling picks up external writes (e.g. iOS app)
        vim.bo[ev.buf].autoread = true
      elseif files_mod.is_masterplan(filepath) then
        files_mod.track_last_shotfile(filepath)
      end
    end,
  })

  -- Reapply when text changes (immediate — extmarks are atomic, no flicker)
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

  -- Auto-reload markdown files when disk changes detected (suppresses W12 dialog)
  -- Plugin operations write shotfiles via silent! write — always reload silently
  vim.api.nvim_create_autocmd('FileChangedShell', {
    group = group,
    pattern = '*.md',
    callback = function()
      vim.v.fcs_choice = 'reload'
    end,
  })

  -- Poll for external changes every second so edits from the iOS app
  -- (or any other tool) are picked up without needing a focus event.
  -- Only runs checktime when the current buffer is a shotfile.
  vim.fn.timer_start(1000, function()
    vim.schedule(function()
      local buf = vim.api.nvim_get_current_buf()
      local filepath = vim.api.nvim_buf_get_name(buf)
      if filepath ~= '' and is_prompts_file(filepath) then
        vim.cmd('silent! checktime')
      end
    end)
  end, { ['repeat'] = -1 })

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

  -- Auto-reload config, fix, and reapply syntax when config.yaml is saved
  local fixing_config = false  -- guard against recursive BufWritePost
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    pattern = 'config.yaml',
    callback = function(ev)
      if fixing_config then return end
      local filepath = vim.api.nvim_buf_get_name(ev.buf)
      -- Only react to shooter config files (global or project-local)
      if filepath:match('shooter/nvim/config%.yaml$') or filepath:match('%.shooter/cfg/nvim/config%.yaml$') then
        local ext_config = require('shooter.core.ext_config')
        -- Fix: strip invalid keys, fill missing defaults (global)
        local is_global = filepath:match('shooter/nvim/config%.yaml$') and not filepath:match('%.shooter/cfg/nvim/config%.yaml$')
        local removed, added = ext_config.fix_config_buffer(ev.buf, is_global)
        -- Silently re-save if fix changed the buffer
        if removed > 0 or added > 0 then
          fixing_config = true
          vim.cmd('noautocmd write')
          fixing_config = false
        end
        ext_config.reload()
        define_highlights()
        M.reapply_all()
        local parts = { 'reloaded' }
        if removed > 0 then table.insert(parts, 'removed ' .. removed .. ' invalid') end
        if added > 0 then table.insert(parts, 'added ' .. added .. ' missing') end
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
    local config = require('shooter.config')
    -- Helper: apply ext_config override for a single highlight group
    -- ext_key: ext_config path (e.g. 'file.open_shots')
    -- hl_name: vim highlight group name (e.g. 'HalShooterOpenShot')
    -- cfg_key: config.lua key (e.g. 'highlight.open_shot')
    -- bg_nil_ok: if true, empty string bg means nil (no background)
    local function apply_override(ext_key, hl_name, cfg_key, bg_nil_ok)
      local ext_bg = ext_config.get(ext_key .. '.color_bg')
      local ext_fg = ext_config.get(ext_key .. '.color_fg')
      if type(ext_bg) == 'string' or type(ext_fg) == 'string' then
        local defaults = config.get(cfg_key) or {}
        local bg = ext_bg or defaults.bg
        -- Treat empty string as nil (no background)
        if bg_nil_ok and bg == '' then bg = nil end
        vim.api.nvim_set_hl(0, hl_name, {
          fg = ext_fg or defaults.fg or '#888888',
          bg = bg,
          bold = defaults.bold or false,
        })
      end
    end
    -- Open shots
    apply_override('file.open_shots', 'HalShooterOpenShot', 'highlight.open_shot')
    -- Open shots title
    apply_override('file.open_shots_title', 'HalShooterOpenShotTitle', 'highlight.open_shot_title')
    -- Closed shots prefix (latest executed)
    apply_override('file.closed_shots_prefix', 'HalShooterDoneShotPrefix', 'highlight.done_shot_prefix', true)
    -- Closed shots title
    apply_override('file.closed_shots_title', 'HalShooterDoneShotTitle', 'highlight.done_shot_title')
    -- Closed shots postfix
    apply_override('file.closed_shots_postfix', 'HalShooterDoneShotPostfix', 'highlight.done_shot_postfix', true)
    -- Day marker prefix (first shot of the day)
    apply_override('file.first_shot_of_the_day_prefix', 'HalShooterDayMarkerPrefix', 'highlight.day_marker_prefix', true)
    -- Day marker title
    apply_override('file.first_shot_of_the_day_title', 'HalShooterDayMarkerTitle', 'highlight.day_marker_title')
    -- Day marker postfix
    apply_override('file.first_shot_of_the_day_postfix', 'HalShooterDayMarkerPostfix', 'highlight.day_marker_postfix', true)
  end
  -- Extmarks are buffer-local — no window targeting needed
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
