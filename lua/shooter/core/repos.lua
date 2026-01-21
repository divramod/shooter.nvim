-- Cross-repo functionality for shooter.nvim
-- Find git repos and create shots in other repos

local config = require('shooter.config')
local utils = require('shooter.utils')

local M = {}

-- Check if a directory is a git repo
function M.is_git_repo(path)
  local git_dir = path .. '/.git'
  return utils.dir_exists(git_dir)
end

-- Get all git repos from configured paths
function M.get_all_repos()
  local repos = {}
  local seen = {}

  -- Add direct paths first
  local direct_paths = config.get('repos.direct_paths') or {}
  for _, path in ipairs(direct_paths) do
    local expanded = utils.expand_path(path)
    if M.is_git_repo(expanded) and not seen[expanded] then
      seen[expanded] = true
      table.insert(repos, {
        path = expanded,
        name = vim.fn.fnamemodify(expanded, ':t'),
      })
    end
  end

  -- Search directories for git repos
  local search_dirs = config.get('repos.search_dirs') or {}
  for _, dir in ipairs(search_dirs) do
    local expanded_dir = utils.expand_path(dir)
    if utils.dir_exists(expanded_dir) then
      -- Find subdirectories that are git repos
      local handle = io.popen('ls -d "' .. expanded_dir .. '"/*/ 2>/dev/null')
      if handle then
        for subdir in handle:lines() do
          -- Remove trailing slash
          subdir = subdir:gsub('/$', '')
          if M.is_git_repo(subdir) and not seen[subdir] then
            seen[subdir] = true
            table.insert(repos, {
              path = subdir,
              name = vim.fn.fnamemodify(subdir, ':t'),
            })
          end
        end
        handle:close()
      end
    end
  end

  -- Sort by name
  table.sort(repos, function(a, b) return a.name < b.name end)
  return repos
end

-- Create a new shot file in a specific repo
function M.create_file_in_repo(repo_path, title)
  local files = require('shooter.core.files')
  local prompts_dir = repo_path .. '/plans/prompts'
  vim.fn.mkdir(prompts_dir, 'p')

  -- Generate filename
  local date = os.date('%Y%m%d')
  local time = os.date('%H%M')
  local safe_title = title:lower():gsub('%s+', '-'):gsub('[^%w%-]', '')
  local filename = string.format('%s_%s_%s.md', date, time, safe_title)
  local filepath = prompts_dir .. '/' .. filename

  -- Create file with title
  local file = io.open(filepath, 'w')
  if not file then
    utils.echo('Failed to create file: ' .. filepath)
    return nil
  end
  file:write('# ' .. title .. '\n\n')
  file:close()

  return filepath
end

-- Show telescope picker to select repo and create file
function M.create_in_repo_picker()
  local repos = M.get_all_repos()
  if #repos == 0 then
    utils.notify('No repos configured. Add repos.search_dirs or repos.direct_paths to config', vim.log.levels.WARN)
    return
  end

  -- First ask for title
  vim.ui.input({ prompt = 'Feature title: ' }, function(title)
    if not title or title == '' then return end

    -- Then show repo picker
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')

    pickers.new({}, {
      prompt_title = 'Select Repository',
      finder = finders.new_table({
        results = repos,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.name,
            ordinal = entry.name,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if entry and entry.value then
            local filepath = M.create_file_in_repo(entry.value.path, title)
            if filepath then
              vim.cmd('edit ' .. vim.fn.fnameescape(filepath))
              utils.echo('Created in ' .. entry.value.name .. ': ' .. vim.fn.fnamemodify(filepath, ':t'))
            end
          end
        end)
        return true
      end,
    }):find()
  end)
end

return M
