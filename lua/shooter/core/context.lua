-- Context file management for shooter.nvim
-- Read and create general/project context files

local utils = require('shooter.utils')
local config = require('shooter.config')
local files = require('shooter.core.files')

local M = {}

-- Get general context file path
function M.get_general_context_path()
  return utils.expand_path(config.get('paths.general_context'))
end

-- Get project context file path (at git root)
function M.get_project_context_path()
  local git_root = files.get_git_root()
  if not git_root then
    return nil
  end
  return git_root .. '/' .. config.get('paths.project_context')
end

-- Read context file with error handling
function M.read_context_file(path)
  if not path then
    return '(No path provided)'
  end

  local content, err = utils.read_file(path)
  if not content then
    return string.format('(Could not read file: %s)', path)
  end

  return content
end

-- Get or create project context file
function M.get_or_create_project_context()
  local context_path = M.get_project_context_path()
  if not context_path then
    return nil, '(Not in a git repository)'
  end

  -- Check if context file exists
  if utils.file_exists(context_path) then
    return context_path, nil
  end

  -- File doesn't exist, create it from template
  local context_dir = utils.get_dirname(context_path)
  utils.ensure_dir(context_dir)

  -- Read template
  local template_path = config.get('paths.project_template')

  -- Try to find template in runtime paths
  local runtime_files = vim.api.nvim_get_runtime_file(template_path, false)
  local template_content = [[## PROJECT-SPECIFIC INSTRUCTIONS
Add project-specific context and instructions here.
]]

  if #runtime_files > 0 then
    local content, _ = utils.read_file(runtime_files[1])
    if content then
      template_content = content
    end
  end

  -- Write the context file
  local success, err = utils.write_file(context_path, template_content)
  if not success then
    return nil, err
  end

  return context_path, nil
end

-- Build context section for message
function M.build_context_section()
  local general_path = M.get_general_context_path()
  local project_path, err = M.get_or_create_project_context()

  local general_content = M.read_context_file(general_path)
  local project_content = project_path and M.read_context_file(project_path) or '(No project context)'

  return {
    general_file = general_path,
    general_content = general_content,
    project_file = project_path or '(No project context file)',
    project_content = project_content,
  }
end

-- Read message template
function M.read_message_template()
  local template_path = config.get('paths.message_template')
  local runtime_files = vim.api.nvim_get_runtime_file(template_path, false)

  if #runtime_files > 0 then
    local content, _ = utils.read_file(runtime_files[1])
    if content then
      return content
    end
  end

  -- Fallback template
  return [[# context
1. this is shot {{shot_num}} of the feature "{{title}}"
2. please read the file {{file_path}} to get more context on what was prompted before
3. you should explicitly not implement the old shots
4. your current task is the shot {{shot_num}}

# Shooter general context ({{general_context_file}})

{{general_context_content}}

# Shooter project context ({{project_context_file}})

{{project_context_content}}
]]
end

return M
