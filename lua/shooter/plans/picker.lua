-- Telescope pickers over plan-related markdown files.
--   M.open(...)       — docs/plans/**/<basename>.md (plan / context / spec / idea)
--   M.open_ideas(...) — docs/plans/<NNNN-slug>/idea.md, mtime-sorted with
--                       a `[ip]`/`[pl]`/... metaplan-section prefix

local M = {}

-- Metaplan section name → 2-char display code used by `pE` rows.
local SECTION_TO_CODE = {
  ['in progress'] = 'ip',
  ['planned']     = 'pl',
  ['next plans']  = 'np',
  ['backlog']     = 'bl',
  ['done']        = 'do',
}
-- Code used for ideas whose plan is not referenced in the metaplan.
local UNKNOWN_CODE = '--'

-- Recursively find all files named `<basename>.md` under `<git_root>/docs/plans`.
-- Returns list of absolute paths sorted by relative path.
function M.find(git_root, basename)
  if not git_root or git_root == '' then return {} end
  local root = git_root .. '/docs/plans'
  if vim.fn.isdirectory(root) ~= 1 then return {} end

  local cmd = {
    'find', root, '-type', 'f', '-name', basename .. '.md',
  }
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then return {} end
  table.sort(out)
  return out
end

-- Build a `{ plan_name -> 2-char section code }` map by parsing the
-- metaplan. Returns an empty table when the metaplan is missing — in
-- that case every plan shotfile gets the UNKNOWN_CODE.
function M.plan_categories(git_root)
  if not git_root or git_root == '' then return {} end
  local metaplan = require('shooter.plans.metaplan')
  local f = io.open(metaplan.get_path(git_root), 'r')
  if not f then return {} end
  local content = f:read('*a') or ''
  f:close()
  local parsed = metaplan.parse(content)
  local map = {}
  for section_name, code in pairs(SECTION_TO_CODE) do
    for _, entry in ipairs(parsed.sections[section_name] or {}) do
      local pn = metaplan.extract_plan_name(entry.text)
      if pn then map[pn] = code end
    end
  end
  return map
end

-- List every docs/plans/<NNNN-slug>/idea.md file (across all plan folders).
-- Returns list of absolute paths sorted by plan name.
function M.find_ideas(git_root)
  if not git_root or git_root == '' then return {} end
  local root = git_root .. '/docs/plans'
  if vim.fn.isdirectory(root) ~= 1 then return {} end
  local out = {}
  for _, name in ipairs(vim.fn.readdir(root)) do
    if name:match('^%d%d%d%d%-[%l%d][%w%-]*$')
        and vim.fn.isdirectory(root .. '/' .. name) == 1 then
      local idea = root .. '/' .. name .. '/idea.md'
      if vim.fn.filereadable(idea) == 1 then
        table.insert(out, idea)
      end
    end
  end
  table.sort(out)
  return out
end

-- Build picker entries from `paths`, stripping `prefix` for display.
-- Each entry: { path, display, ordinal }.
local function make_entries(paths, prefix)
  local entries = {}
  for _, p in ipairs(paths) do
    local rel = p:sub(#prefix + 1)
    table.insert(entries, { path = p, display = rel, ordinal = rel })
  end
  return entries
end

-- Sort entries in-place by mtime descending with filename ascending tiebreak,
-- then rewrite each entry's display to append "(<age>)" for quick recency
-- scanning. Mirrors the shotfile picker's "change age, then alphabetical"
-- behavior so plans cluster the same way users expect.
function M.sort_by_age_with_tiebreak(entries)
  local recency = require('shooter.telescope.recency')
  for _, e in ipairs(entries) do
    e._mtime = recency.file_mtime(e.path)
  end
  table.sort(entries, function(a, b)
    if a._mtime ~= b._mtime then return a._mtime > b._mtime end
    return (a.display or ''):lower() < (b.display or ''):lower()
  end)
  local now = os.time()
  for _, e in ipairs(entries) do
    e.display = recency.append_age(e.display, e._mtime, now)
    e.ordinal = e.display
  end
  return entries
end

-- Show a telescope picker over `entries` and edit the selected file.
local function show_picker(entries, opts)
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local previewers = require('telescope.previewers')
  local utils = require('shooter.utils')

  pickers.new({}, {
    prompt_title = opts.prompt_title,
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry.path,
          display = entry.display,
          ordinal = entry.ordinal or entry.display,
          path = entry.path,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = opts.preview_title,
      define_preview = function(self, entry)
        local content = utils.read_file(entry.path) or ''
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false,
          vim.split(content, '\n'))
        vim.bo[self.state.bufnr].filetype = 'markdown'
      end,
    }),
    layout_strategy = 'vertical',
    layout_config = { width = 0.9, height = 0.9, preview_height = 0.5 },
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry and entry.path then
          vim.cmd('edit ' .. vim.fn.fnameescape(entry.path))
        end
      end)
      return true
    end,
  }):find()
end

-- Open a telescope picker of docs/plans/**/<basename>.md and edit the
-- selected file.
function M.open(git_root, basename)
  local paths = M.find(git_root, basename)
  if #paths == 0 then
    require('shooter.utils').echo(
      string.format('No %s.md files under docs/plans/', basename))
    return
  end
  show_picker(make_entries(paths, git_root .. '/docs/plans/'), {
    prompt_title  = 'Plans: ' .. basename .. '.md',
    preview_title = basename .. '.md',
  })
end

-- Open a telescope picker of docs/plans/<NNNN-slug>/idea.md files (the
-- per-plan idea files managed by `pe`/`pf`) and edit the selected file.
-- Entries are sorted newest-first by mtime (alphabetical tiebreak), each
-- row prefixed with the metaplan section code (`[ip]`/`[pl]`/`[np]`/
-- `[bl]`/`[do]`, or `[--]` when the plan isn't in the metaplan) and
-- suffixed with "(<age>)".
function M.open_ideas(git_root)
  local paths = M.find_ideas(git_root)
  if #paths == 0 then
    require('shooter.utils').echo(
      'No idea.md files under docs/plans/')
    return
  end
  -- Display string is the plan name (parent folder), since the filename is
  -- always "idea.md" and would be useless for picking.
  local entries = {}
  for _, p in ipairs(paths) do
    local plan_name = p:match('docs/plans/([^/]+)/idea%.md$') or p
    table.insert(entries, { path = p, display = plan_name, ordinal = plan_name })
  end
  M.sort_by_age_with_tiebreak(entries)
  local categories = M.plan_categories(git_root)
  for _, e in ipairs(entries) do
    local plan_name = e.path:match('docs/plans/([^/]+)/idea%.md$') or ''
    local code = categories[plan_name] or UNKNOWN_CODE
    e.display = string.format('[%s] %s', code, e.display)
    e.ordinal = e.display
  end
  show_picker(entries, {
    prompt_title  = 'Plan ideas',
    preview_title = 'idea.md',
  })
end

return M
