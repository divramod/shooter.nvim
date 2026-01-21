-- Inbox module for "get munition" task import
-- Discovers inbox files and parses next actions

local config = require('shooter.config')
local utils = require('shooter.utils')

local M = {}

-- Get all inbox markdown files from configured paths
function M.get_inbox_files()
  local files = {}
  local seen = {}

  -- Add direct file paths first
  local direct_paths = config.get('inbox.direct_paths') or {}
  for _, path in ipairs(direct_paths) do
    local expanded = utils.expand_path(path)
    if utils.file_exists(expanded) and not seen[expanded] then
      seen[expanded] = true
      table.insert(files, {
        path = expanded,
        name = vim.fn.fnamemodify(expanded, ':t'),
        display = vim.fn.fnamemodify(expanded, ':~'),
      })
    end
  end

  -- Search directories for markdown files
  local search_dirs = config.get('inbox.search_dirs') or {}
  for _, dir in ipairs(search_dirs) do
    local expanded_dir = utils.expand_path(dir)
    if utils.dir_exists(expanded_dir) then
      local handle = io.popen('find "' .. expanded_dir .. '" -name "*.md" -type f 2>/dev/null')
      if handle then
        for filepath in handle:lines() do
          if not seen[filepath] then
            seen[filepath] = true
            table.insert(files, {
              path = filepath,
              name = vim.fn.fnamemodify(filepath, ':t'),
              display = vim.fn.fnamemodify(filepath, ':~'),
            })
          end
        end
        handle:close()
      end
    end
  end

  -- Sort by name
  table.sort(files, function(a, b) return a.name < b.name end)
  return files
end

-- Parse next actions from a markdown file
-- Looks for: lines starting with "- [ ]" or "#"/"##" headers
function M.parse_next_actions(filepath)
  local content, err = utils.read_file(filepath)
  if not content then return {} end

  local actions = {}
  local lines = vim.split(content, '\n')
  local current_action = nil

  for i, line in ipairs(lines) do
    -- Check for "- [ ]" checkbox (unchecked task)
    if line:match('^%s*%-%s*%[%s*%]') then
      if current_action then
        table.insert(actions, current_action)
      end
      current_action = {
        type = 'checkbox',
        title = line:gsub('^%s*%-%s*%[%s*%]%s*', ''),
        start_line = i,
        end_line = i,
        lines = { line },
        raw_line = line,
      }
    -- Check for # or ## headers (but not ###+ which are sub-sections)
    elseif line:match('^##?%s+[^#]') then
      if current_action then
        table.insert(actions, current_action)
      end
      current_action = {
        type = 'header',
        title = line:gsub('^##+%s*', ''),
        start_line = i,
        end_line = i,
        lines = { line },
        raw_line = line,
      }
    -- Continuation of current action (for headers, capture content until next action)
    elseif current_action and current_action.type == 'header' then
      -- Stop at next header or checkbox
      if line:match('^#') or line:match('^%s*%-%s*%[') then
        table.insert(actions, current_action)
        current_action = nil
        -- Re-process this line
        if line:match('^%s*%-%s*%[%s*%]') then
          current_action = {
            type = 'checkbox',
            title = line:gsub('^%s*%-%s*%[%s*%]%s*', ''),
            start_line = i,
            end_line = i,
            lines = { line },
            raw_line = line,
          }
        elseif line:match('^##?%s+[^#]') then
          current_action = {
            type = 'header',
            title = line:gsub('^##+%s*', ''),
            start_line = i,
            end_line = i,
            lines = { line },
            raw_line = line,
          }
        end
      else
        -- Continue capturing content for header action
        current_action.end_line = i
        table.insert(current_action.lines, line)
      end
    end
  end

  -- Don't forget the last action
  if current_action then
    table.insert(actions, current_action)
  end

  return actions
end

-- Remove actions from source file by line numbers
function M.remove_actions_from_file(filepath, actions)
  local content, err = utils.read_file(filepath)
  if not content then return false end

  local lines = vim.split(content, '\n')

  -- Build set of lines to remove
  local lines_to_remove = {}
  for _, action in ipairs(actions) do
    for i = action.start_line, action.end_line do
      lines_to_remove[i] = true
    end
  end

  -- Filter out removed lines
  local new_lines = {}
  for i, line in ipairs(lines) do
    if not lines_to_remove[i] then
      table.insert(new_lines, line)
    end
  end

  -- Write back
  local new_content = table.concat(new_lines, '\n')
  return utils.write_file(filepath, new_content)
end

-- Get action content for preview (trim trailing empty lines)
function M.get_action_content(action)
  local lines = action.lines
  -- Trim trailing empty lines
  while #lines > 0 and lines[#lines]:match('^%s*$') do
    table.remove(lines)
  end
  return table.concat(lines, '\n')
end

return M
