-- Worktree switching — buffer close + cd + edit-target.
-- Pulled out of shooter/tools/git_worktree.lua during plan 0001 phase 004 T007.

local repo = require('shooter.tools.git_worktree.repo')
local list = require('shooter.tools.git_worktree.list')
local state = require('shooter.tools.git_worktree.state')

local M = {}

---@param target_root string
function M.switch_to_worktree(target_root)
  state.save_last_worktree()

  local rel_file = repo.get_relative_file()

  local bufs = vim.api.nvim_list_bufs()
  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end

  vim.cmd('cd ' .. vim.fn.fnameescape(target_root))

  local target_file
  if rel_file then
    local candidate = target_root .. '/' .. rel_file
    if vim.fn.filereadable(candidate) == 1 then
      target_file = candidate
    end
  end

  if not target_file then
    target_file = target_root .. '/README.md'
    if vim.fn.filereadable(target_file) ~= 1 then
      target_file = target_root
    end
  end

  vim.cmd('edit ' .. vim.fn.fnameescape(target_file))
end

---@param number? number
function M.switch_to(number, pick_fn)
  local worktrees = list.get_numbered_worktrees()

  if number then
    local num_str = tostring(number)
    for _, wt in ipairs(worktrees) do
      if wt.name == num_str then
        M.switch_to_worktree(wt.path)
        return
      end
    end
    return
  end

  -- No number given: open telescope picker via injected callback
  if pick_fn then pick_fn(worktrees) end
end

function M.to_main()
  local main_path = list.get_main_worktree()
  if not main_path then return end
  M.switch_to_worktree(main_path)
end

function M.to_last()
  local last_id = state.read_last_worktree()
  if not last_id then return end

  if last_id == 'main' then
    M.to_main()
    return
  end

  local repo_name = repo.get_repo_name()
  if not repo_name then return end
  local target = repo.WORKTREE_BASE .. '/' .. repo_name .. '/' .. last_id
  if vim.fn.isdirectory(target) ~= 1 then return end
  M.switch_to_worktree(target)
end

return M
