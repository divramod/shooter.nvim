-- Git worktree switching for shooter.nvim
-- Switch between git worktrees under ~/.hal/git/worktree/

local M = {}

local WORKTREE_BASE = vim.fn.expand('~/.hal/git/worktree')

-- Get the repo name, handling both main repo and worktree contexts
local function get_repo_name()
  -- Get the git toplevel (works from cwd or buffer dir)
  local git_root
  local result = vim.fn.systemlist('git rev-parse --show-toplevel')
  if vim.v.shell_error == 0 and #result > 0 then
    git_root = result[1]
  else
    local buf_dir = vim.fn.expand('%:p:h')
    if buf_dir ~= '' then
      result = vim.fn.systemlist('git -C ' .. vim.fn.shellescape(buf_dir) .. ' rev-parse --show-toplevel')
      if vim.v.shell_error == 0 and #result > 0 then
        git_root = result[1]
      end
    end
  end
  if not git_root then return nil, nil end

  -- Check if we're inside a worktree under WORKTREE_BASE
  -- Path pattern: ~/.hal/git/worktree/<repo-name>/<worktree-name>
  local wt_prefix = WORKTREE_BASE .. '/'
  if git_root:sub(1, #wt_prefix) == wt_prefix then
    local rest = git_root:sub(#wt_prefix + 1)
    local repo_name = rest:match('^([^/]+)/')
    if repo_name then
      return repo_name, git_root
    end
  end

  -- Not in a worktree dir — use the directory name as repo name
  local name = vim.fn.fnamemodify(git_root, ':t')
  return name, git_root
end

-- Run a git command, trying cwd first, then buffer's directory
local function git_cmd(cmd)
  local lines = vim.fn.systemlist(cmd)
  if vim.v.shell_error == 0 then
    return lines
  end
  local buf_dir = vim.fn.expand('%:p:h')
  if buf_dir ~= '' then
    lines = vim.fn.systemlist('git -C ' .. vim.fn.shellescape(buf_dir) .. ' ' .. cmd:gsub('^git ', ''))
    if vim.v.shell_error == 0 then
      return lines
    end
  end
  return nil
end

-- Get list of worktrees for current repo from git worktree list
local function get_worktrees()
  local lines = git_cmd('git worktree list --porcelain')
  if not lines then
    return {}
  end
  local worktrees = {}
  local current = {}
  for _, line in ipairs(lines) do
    if line:match('^worktree ') then
      current = { path = line:match('^worktree (.+)') }
    elseif line:match('^branch ') then
      current.branch = line:match('^branch refs/heads/(.+)')
    elseif line == '' then
      if current.path then
        table.insert(worktrees, current)
      end
      current = {}
    elseif line:match('^bare') then
      current.bare = true
    end
  end
  if current.path then
    table.insert(worktrees, current)
  end
  return worktrees
end

-- Find the main worktree (first one listed, which is always the main)
local function get_main_worktree()
  local worktrees = get_worktrees()
  if #worktrees > 0 then
    return worktrees[1].path
  end
  return nil
end

-- Get numbered worktrees under ~/.hal/git/worktree/<repo>/
local function get_numbered_worktrees()
  local repo_name = get_repo_name()
  if not repo_name then return {} end

  local repo_wt_dir = WORKTREE_BASE .. '/' .. repo_name
  if vim.fn.isdirectory(repo_wt_dir) ~= 1 then
    return {}
  end

  local entries = vim.fn.readdir(repo_wt_dir)
  local numbered = {}
  for _, entry in ipairs(entries) do
    local full_path = repo_wt_dir .. '/' .. entry
    if vim.fn.isdirectory(full_path) == 1 then
      table.insert(numbered, {
        name = entry,
        path = full_path,
      })
    end
  end
  table.sort(numbered, function(a, b) return a.name < b.name end)
  return numbered
end

-- Get relative file path from git root
local function get_relative_file()
  local file = vim.fn.expand('%:p')
  if file == '' then return nil end
  local _, root = get_repo_name()
  if not root then return nil end
  if file:sub(1, #root) == root then
    return file:sub(#root + 2)
  end
  return nil
end

-- Get the .hal/git/worktree/ directory in the main repo
local function get_repo_wt_state_dir()
  local main_path = get_main_worktree()
  if not main_path then return nil end
  return main_path .. '/.hal/git/worktree'
end

-- Ensure .hal/git/worktree/.gitignore contains LAST
local function ensure_gitignore()
  local state_dir = get_repo_wt_state_dir()
  if not state_dir then return end

  vim.fn.mkdir(state_dir, 'p')
  local gitignore_path = state_dir .. '/.gitignore'
  local needs_commit = false

  if vim.fn.filereadable(gitignore_path) == 1 then
    local content = vim.fn.readfile(gitignore_path)
    local has_last = false
    for _, line in ipairs(content) do
      if line == 'LAST' then
        has_last = true
        break
      end
    end
    if not has_last then
      table.insert(content, 'LAST')
      vim.fn.writefile(content, gitignore_path)
      needs_commit = true
    end
  else
    vim.fn.writefile({ 'LAST' }, gitignore_path)
    needs_commit = true
  end

  if needs_commit then
    local main_path = get_main_worktree()
    if main_path then
      vim.fn.system('git -C ' .. vim.fn.shellescape(main_path)
        .. ' add ' .. vim.fn.shellescape(gitignore_path))
      vim.fn.system('git -C ' .. vim.fn.shellescape(main_path)
        .. ' commit -m "chore(hal): add .hal/git/worktree/.gitignore"')
    end
  end
end

-- Save current worktree identifier to LAST file
local function save_last_worktree()
  local _, current_root = get_repo_name()
  if not current_root then return end

  local state_dir = get_repo_wt_state_dir()
  if not state_dir then return end

  ensure_gitignore()

  -- Determine the worktree identifier (folder name or "main")
  local wt_prefix = WORKTREE_BASE .. '/'
  local identifier
  if current_root:sub(1, #wt_prefix) == wt_prefix then
    local rest = current_root:sub(#wt_prefix + 1)
    -- rest = "<repo>/<worktree-name>"
    identifier = rest:match('^[^/]+/(.+)$')
  else
    identifier = 'main'
  end

  if identifier then
    vim.fn.mkdir(state_dir, 'p')
    vim.fn.writefile({ identifier }, state_dir .. '/LAST')
  end
end

-- Read last worktree identifier from LAST file
local function read_last_worktree()
  local state_dir = get_repo_wt_state_dir()
  if not state_dir then return nil end

  local last_file = state_dir .. '/LAST'
  if vim.fn.filereadable(last_file) ~= 1 then return nil end

  local lines = vim.fn.readfile(last_file)
  if #lines > 0 and lines[1] ~= '' then
    return lines[1]
  end
  return nil
end

-- Close all buffers except current, then switch to target file
local function switch_to_worktree(target_root)
  -- Save current worktree as "last" before switching
  save_last_worktree()

  local rel_file = get_relative_file()

  -- Close all buffers
  local bufs = vim.api.nvim_list_bufs()
  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end

  -- Change working directory
  vim.cmd('cd ' .. vim.fn.fnameescape(target_root))

  -- Try to open the same file in the new worktree
  local target_file
  if rel_file then
    local candidate = target_root .. '/' .. rel_file
    if vim.fn.filereadable(candidate) == 1 then
      target_file = candidate
    end
  end

  -- Fallback to README.md
  if not target_file then
    target_file = target_root .. '/README.md'
    if vim.fn.filereadable(target_file) ~= 1 then
      target_file = target_root
    end
  end

  vim.cmd('edit ' .. vim.fn.fnameescape(target_file))
end

-- Switch to worktree by number
function M.switch_to(number)
  local worktrees = get_numbered_worktrees()

  if number then
    -- Find worktree matching the number
    local num_str = tostring(number)
    for _, wt in ipairs(worktrees) do
      if wt.name == num_str then
        switch_to_worktree(wt.path)
        return
      end
    end
    return
  end

  -- No number given: open telescope picker
  M.pick_worktree(worktrees)
end

-- Telescope picker for worktrees
function M.pick_worktree(worktrees)
  worktrees = worktrees or get_numbered_worktrees()

  if #worktrees == 0 then
    return
  end

  local ok, _ = pcall(require, 'telescope')
  if not ok then
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  -- Also include main worktree
  local entries = {}
  local main_path = get_main_worktree()
  if main_path then
    table.insert(entries, { name = 'main', path = main_path })
  end
  for _, wt in ipairs(worktrees) do
    table.insert(entries, wt)
  end

  -- Determine current worktree to mark it
  local _, current_root = get_repo_name()

  pickers.new({}, {
    prompt_title = 'Git Worktrees',
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        local marker = ''
        if current_root and entry.path == current_root then
          marker = ' (CURRENT)'
        end
        local display = entry.name .. '  ' .. entry.path .. marker
        return {
          value = entry,
          display = display,
          ordinal = entry.name,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          switch_to_worktree(selection.value.path)
        end
      end)
      return true
    end,
  }):find()
end

-- Switch to last worktree
function M.to_last()
  local last_id = read_last_worktree()
  if not last_id then
    return
  end

  if last_id == 'main' then
    M.to_main()
    return
  end

  -- It's a numbered worktree
  local repo_name = get_repo_name()
  if not repo_name then
    return
  end
  local target = WORKTREE_BASE .. '/' .. repo_name .. '/' .. last_id
  if vim.fn.isdirectory(target) ~= 1 then
    return
  end
  switch_to_worktree(target)
end

-- Switch back to main worktree
function M.to_main()
  local main_path = get_main_worktree()
  if not main_path then
    return
  end
  switch_to_worktree(main_path)
end

-- Expose main worktree path for other modules (e.g., shotfile picker)
M.get_main_worktree = get_main_worktree

return M
