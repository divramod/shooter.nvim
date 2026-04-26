-- shooter.plans.metaplan public surface — re-exports the 30-fn API.
-- No logic; every function lives in a sibling sub-module.

local parse = require('shooter.plans.metaplan.parse')
local render_mod = require('shooter.plans.metaplan.render')
local numbering = require('shooter.plans.metaplan.numbering')
local io_mod = require('shooter.plans.metaplan.io')
local meta = require('shooter.plans.metaplan.meta')
local idea = require('shooter.plans.metaplan.idea')
local rename = require('shooter.plans.metaplan.rename')
local delete = require('shooter.plans.metaplan.delete')
local mark_done = require('shooter.plans.metaplan.mark_done')
local fix = require('shooter.plans.metaplan.fix')

local M = {}

-- meta
M.get_path = meta.get_path
M.get_alias = meta.get_alias
M.get_title = meta.get_title
M.idea_path = meta.idea_path
M.edit_plan_at_line = meta.edit_plan_at_line
M.open_plan_file = meta.open_plan_file

-- parse
M.slugify = parse.slugify
M.parse = parse.parse
M.extract_extras = parse.extract_extras
M.extract_plan_name = parse.extract_plan_name

-- render
M.render = render_mod.render

-- numbering
M.classify_plan = numbering.classify_plan
M.plan_files_in_worktree = numbering.plan_files_in_worktree
M.list_worktree_roots = numbering.list_worktree_roots
M.collect_used_numbers = numbering.collect_used_numbers
M.next_plans_number_at = numbering.next_plans_number_at
M.next_free_plan_number = numbering.next_free_plan_number

-- io
M.commit_plans = io_mod.commit_plans

-- idea
M.ensure_plan_idea = idea.ensure_plan_idea
M.apply_extras_to_idea = idea.apply_extras_to_idea
M.new_plan = idea.new_plan

-- rename
M.rewrite_metaplan_line = rename.rewrite_metaplan_line
M.remove_metaplan_entry = rename.remove_metaplan_entry
M.rename_plan = rename.rename_plan

-- delete
M.is_stub_file = delete.is_stub_file
M.folder_has_content = delete.folder_has_content
M.delete_plan_preflight = delete.delete_plan_preflight
M.delete_plan = delete.delete_plan

-- mark_done
M.mark_done = mark_done.mark_done

-- fix
M.fix = fix.fix

return M
