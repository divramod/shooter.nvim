-- fix() orchestrator: parse → reclassify → extract extras to ideas →
-- gap-fill renumbering → render → folder renames in main.

local util = require('shooter.plans.metaplan.util')
local io_mod = require('shooter.plans.metaplan.io')
local parse = require('shooter.plans.metaplan.parse')
local render_mod = require('shooter.plans.metaplan.render')
local numbering = require('shooter.plans.metaplan.numbering')
local meta = require('shooter.plans.metaplan.meta')
local idea = require('shooter.plans.metaplan.idea')
local rename = require('shooter.plans.metaplan.rename')

local M = {}

function M.fix(git_root)
  if not git_root or git_root == '' then return false, 'no git root' end
  local path = meta.get_path(git_root)
  vim.fn.mkdir(git_root .. '/docs/plans', 'p')

  local worktree_roots = numbering.list_worktree_roots(git_root)

  local bufnr = io_mod.find_loaded_buf(path)
  local content
  if bufnr then
    content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
  else
    content = io_mod.read_file(path) or ''
  end

  local parsed = parse.parse(content)

  -- 1. `## done` is sticky.
  local done_entries = parsed.sections['done'] or {}
  local in_done_slugs = {}
  for _, e in ipairs(done_entries) do
    local slug = (e.text or ''):match('%d%d%d%d%-([%l%d][%w%-]*)')
    if slug then in_done_slugs[slug] = true end
  end

  -- 2. Snapshot pre-existing folders (orphan-adoption, lock decision).
  local pre_existing_folders = {}
  for _, root in ipairs(worktree_roots) do
    local plans_dir = root .. '/docs/plans'
    if vim.fn.isdirectory(plans_dir) == 1 then
      for _, name in ipairs(vim.fn.readdir(plans_dir)) do
        local pn = name:match('^(%d%d%d%d%-[%l%d][%w%-]*)$')
        if pn and vim.fn.isdirectory(plans_dir .. '/' .. name) == 1 then
          pre_existing_folders[pn] = true
        end
      end
    end
  end

  -- Track each entry's original position + which started in `## next plans`.
  local original_position = {}
  local original_in_next_plans = {}
  do
    local pos = 0
    for _, section_name in ipairs(util.AUTO_SECTIONS) do
      for _, entry in ipairs(parsed.sections[section_name] or {}) do
        pos = pos + 1
        original_position[entry] = pos
        if section_name == 'next plans' then
          original_in_next_plans[entry] = true
        end
      end
    end
    for _, entry in ipairs(parsed.sections['backlog'] or {}) do
      pos = pos + 1
      original_position[entry] = pos
    end
  end

  local plan_entries = {}
  local seen_plan_names = {}
  local folder_backed_slugs = {}
  local seen_folderless_slugs = {}
  local function entry_has_folder(plan_name)
    if not plan_name then return false end
    for _, root in ipairs(worktree_roots) do
      if vim.fn.isdirectory(root .. '/docs/plans/' .. plan_name) == 1 then
        return true
      end
    end
    return false
  end
  local function add_plan_entry(entry)
    local plan_name = parse.extract_plan_name(entry.text or '')
    if plan_name then
      local slug = plan_name:match('^%d%d%d%d%-(.*)$')
      if seen_plan_names[plan_name] then return end
      if slug and in_done_slugs[slug] then return end
      if entry_has_folder(plan_name) then
        seen_plan_names[plan_name] = true
        if slug then folder_backed_slugs[slug] = true end
        table.insert(plan_entries, entry)
        return
      end
      if slug and (folder_backed_slugs[slug]
          or seen_folderless_slugs[slug]) then
        return
      end
      seen_plan_names[plan_name] = true
      if slug then seen_folderless_slugs[slug] = true end
    end
    table.insert(plan_entries, entry)
  end
  for _, section_name in ipairs(util.AUTO_SECTIONS) do
    for _, entry in ipairs(parsed.sections[section_name] or {}) do
      add_plan_entry(entry)
    end
  end
  for _, entry in ipairs(parsed.sections['backlog'] or {}) do
    add_plan_entry(entry)
  end
  local docs_plans = git_root .. '/docs/plans'
  if vim.fn.isdirectory(docs_plans) == 1 then
    for _, name in ipairs(vim.fn.readdir(docs_plans)) do
      local pn = name:match('^(%d%d%d%d%-[%l%d][%w%-]*)$')
      if pn and vim.fn.isdirectory(docs_plans .. '/' .. name) == 1 then
        add_plan_entry({ text = pn, children = {} })
      end
    end
  end

  -- 3. Move description-paren + child notes into each plan's idea.md.
  local function extract_into_idea(entry)
    local plan_name = parse.extract_plan_name(entry.text)
    if not plan_name then return end
    local paren, notes, cleaned, had = parse.extract_extras(entry)
    if had then
      idea.apply_extras_to_idea(git_root, plan_name, paren, notes)
      entry.text = cleaned
      entry.children = {}
    end
  end
  for _, entry in ipairs(plan_entries) do extract_into_idea(entry) end
  for _, entry in ipairs(done_entries) do extract_into_idea(entry) end

  -- 4. Auto-classify by file presence.
  local classified = {
    ['in progress'] = {},
    ['planned'] = {},
    ['specified'] = {},
    ['next plans'] = {},
  }
  for _, entry in ipairs(plan_entries) do
    local plan_name = parse.extract_plan_name(entry.text)
    local section = (plan_name
        and numbering.classify_plan(git_root, plan_name, worktree_roots))
      or 'next plans'
    table.insert(classified[section], entry)
  end

  -- 5. Sort.
  for _, sec in ipairs({ 'in progress', 'planned', 'specified' }) do
    table.sort(classified[sec], function(a, b) return a.text < b.text end)
  end
  table.sort(classified['next plans'], function(a, b)
    local oa = original_position[a]
    local ob = original_position[b]
    if oa and ob then return oa < ob end
    if oa then return true end
    if ob then return false end
    return a.text < b.text
  end)

  parsed.sections = classified
  parsed.sections['done'] = done_entries
  parsed.order = util.SECTIONS

  -- 6. Snapshot for post-render rename.
  local next_pre = {}
  for i, entry in ipairs(parsed.sections['next plans'] or {}) do
    next_pre[i] = entry.text:match('^(%d%d%d%d%-[%l%d][%w%-]*)')
  end

  local used = numbering.collect_used_numbers(git_root, parsed.sections, worktree_roots)

  local function is_locked(entry)
    local pn = entry.text:match('^(%d%d%d%d%-[%l%d][%w%-]*)')
    if not pn then return false end
    if original_in_next_plans[entry] then return false end
    return pre_existing_folders[pn] == true
  end

  local new = render_mod.render(parsed, meta.get_title(git_root),
    { used_numbers = used, is_locked = is_locked })

  if bufnr then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false,
      vim.split(new:gsub('\n$', ''), '\n', { plain = true }))
    vim.api.nvim_buf_call(bufnr, function() vim.cmd('silent! write') end)
  else
    if not io_mod.write_file(path, new) then return false, 'cannot write ' .. path end
  end

  -- 7. Rename plan folders for renumbered `## next plans` entries.
  local renames = {}
  for i, entry in ipairs(parsed.sections['next plans'] or {}) do
    local pre = next_pre[i]
    local post = entry.text:match('^(%d%d%d%d%-[%l%d][%w%-]*)')
    if pre and post and pre ~= post then
      table.insert(renames, { pre = pre, post = post })
    end
  end
  for _, r in ipairs(renames) do
    rename.rename_plan_folder(git_root, r.pre, r.post)
  end

  return true
end

return M
