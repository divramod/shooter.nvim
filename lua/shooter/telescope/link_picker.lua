-- Telescope picker for opening links extracted from a buffer or tmux panes.
local M = {}

local recency = require('shooter.telescope.recency')

-- Try to load nvim-web-devicons for nerd-font icons. Returns nil if the
-- plugin isn't installed; callers fall back to plain unicode glyphs.
local function load_devicons()
  local ok, devicons = pcall(require, 'nvim-web-devicons')
  if ok then return devicons end
  return nil
end

-- Fallback unicode glyphs used when nvim-web-devicons isn't installed.
local FALLBACK_ICONS = {
  web = '\u{f0ac}',   --  globe
  dir = '\u{f07b}',   --  folder
  file = '\u{f15b}',  --  generic file
  other = '\u{f128}', --  question
}

-- Icon for a link entry. Uses nvim-web-devicons when available.
local function icon_for(entry)
  local devicons = load_devicons()

  if entry.kind == 'web' then
    return FALLBACK_ICONS.web
  end
  if entry.kind == 'dir' then
    if devicons then
      local icon = devicons.get_icon(entry.target, nil, { default = false })
      if icon then return icon end
    end
    return FALLBACK_ICONS.dir
  end

  -- file / other: look up by extension, fall back to filename.
  local basename = entry.target:match('([^/]+)$') or entry.target
  local ext = (basename:match('%.([%w]+)$') or ''):lower()
  if devicons then
    local icon = devicons.get_icon(basename, ext ~= '' and ext or nil,
      { default = true })
    if icon then return icon end
  end
  return entry.kind == 'file' and FALLBACK_ICONS.file or FALLBACK_ICONS.other
end

-- Expand ~ in a local-looking path so fs_stat can find it.
local function expand_local(target)
  if target:sub(1, 1) == '~' then
    return (os.getenv('HOME') or '') .. target:sub(2)
  end
  return target
end

-- Return the relative age string ("5m ago", "2h 5m ago", ...) for a link
-- whose target is a local file or directory. Returns nil for web links or
-- missing files.
function M.age_for(entry, now)
  if entry.kind ~= 'file' and entry.kind ~= 'dir' then return nil end
  local path = expand_local(entry.target)
  local mtime = recency.file_mtime(path)
  if mtime == 0 then return nil end
  now = now or os.time()
  return recency.format_relative(now - mtime)
end

-- Format a link entry's display string.
--   <icon> <link> (line:col) (5m ago)        -- current-buffer picker
--   [source] <icon> <link> (line:col) (5m ago)  -- tmux picker
function M.format_entry(entry, with_source, now)
  local icon = icon_for(entry)
  local position = string.format('(%d:%d)', entry.line, entry.col)
  local age = M.age_for(entry, now)
  local age_suffix = age and (' (' .. age .. ')') or ''
  if with_source and entry.source then
    return string.format('[%s] %s %s %s%s',
      entry.source, icon, entry.target, position, age_suffix)
  end
  return string.format('%s %s %s%s', icon, entry.target, position, age_suffix)
end

-- Decide the layout width given the widest display line and the total
-- available columns. Exposed so it can be unit-tested.
--
-- Rules:
--   * Reserve `padding` cells for telescope borders + gutter + scrollbar.
--   * If every line fits in the narrow default (80 % of cols), keep that
--     width — full-width popups feel overwhelming when they aren't needed.
--   * Otherwise grow to exactly what's needed, capped at the full window.
function M.compute_width(max_display, cols, padding)
  padding = padding or 6
  local default = math.floor(cols * 0.8)
  if default < 1 then default = cols end
  if max_display + padding <= default then
    return default
  end
  return cols
end

local function make_entry(with_source, now)
  return function(entry)
    local display = M.format_entry(entry, with_source, now)
    return {
      value = entry,
      display = display,
      ordinal = display,
    }
  end
end

-- Open the picker with the given list of link entries. Entries should be
-- sorted by the caller (e.g. by position in file).
function M.open(entries, opts)
  opts = opts or {}
  if #entries == 0 then
    vim.notify('[shooter] no links found', vim.log.levels.INFO)
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local links = require('shooter.tools.links')

  -- Pre-format entries once so we can measure the widest line and pick a
  -- sensible width for the layout. If every entry fits in the default 80 %
  -- layout we keep the narrow look; only expand to full width when at
  -- least one entry would otherwise be truncated.
  local now = os.time()
  local max_display = 0
  for _, e in ipairs(entries) do
    local w = vim.fn.strdisplaywidth(M.format_entry(e, opts.with_source, now))
    if w > max_display then max_display = w end
  end

  local width_fn = function(_, cols, _)
    return M.compute_width(max_display, cols)
  end

  pickers.new({}, {
    prompt_title = opts.title or 'Links',
    layout_strategy = 'vertical',
    layout_config = { width = width_fn, height = 0.6, preview_height = 0.3 },
    initial_mode = 'normal',
    finder = finders.new_table({
      results = entries,
      entry_maker = make_entry(opts.with_source, now),
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry and entry.value then links.open(entry.value) end
      end)
      map('n', '<C-n>', actions.move_selection_next, { desc = 'next' })
      map('n', '<C-p>', actions.move_selection_previous, { desc = 'prev' })
      map('i', '<C-n>', actions.move_selection_next, { desc = 'next' })
      map('i', '<C-p>', actions.move_selection_previous, { desc = 'prev' })
      map('n', '<C-c>', actions.close, { desc = 'close' })
      map('n', 'q', actions.close, { desc = 'close' })
      return true
    end,
  }):find()
end

return M
