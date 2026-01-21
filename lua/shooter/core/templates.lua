-- Template loading and variable replacement for shooter.nvim
-- Provides abstracted template system with systematic variable naming

local utils = require('shooter.utils')
local config = require('shooter.config')
local files = require('shooter.core.files')

local M = {}

-- Trim trailing whitespace (fixes double empty lines)
local function trim_trailing(content)
  if not content then return "" end
  return content:gsub('%s+$', '')
end

-- Replace home directory with ~ for better readability
local function shorten_home(path)
  if not path then return "" end
  local home = os.getenv('HOME')
  if home and path:sub(1, #home) == home then
    return '~' .. path:sub(#home + 1)
  end
  return path
end

-- Get repository name from git remote or folder name
function M.get_repo_name()
  local git_root = files.get_git_root()
  if not git_root then
    return vim.fn.fnamemodify(utils.cwd(), ':t')
  end

  -- Try to get from git remote origin
  local result = utils.system('git remote get-url origin 2>/dev/null')
  if result and result ~= '' then
    -- Parse git@github.com:user/repo.git or https://github.com/user/repo.git
    local repo = result:match('[:/]([^/]+/[^/%.]+)%.?g?i?t?%s*$')
    if repo then return repo end
    -- Just get the last part
    repo = result:match('([^/]+)%.git%s*$') or result:match('([^/]+)%s*$')
    if repo then return repo end
  end

  -- Fallback to folder name
  return vim.fn.fnamemodify(git_root, ':t')
end

-- Load a template file with priority: project > global > plugin fallback
-- @param filename string The template filename (e.g., 'shooter-context-instructions.md')
-- @return string The template content
function M.load_template(filename)
  local git_root = files.get_git_root()

  -- Priority 1: Project-specific (./.shooter.nvim/)
  if git_root then
    local project_path = git_root .. '/.shooter.nvim/' .. filename
    local content = utils.read_file(project_path)
    if content then return trim_trailing(content) end
  end

  -- Priority 2: Global (~/.config/shooter.nvim/)
  local global_path = utils.expand_path('~/.config/shooter.nvim/' .. filename)
  local content = utils.read_file(global_path)
  if content then return trim_trailing(content) end

  -- Priority 3: Plugin templates folder
  local runtime_files = vim.api.nvim_get_runtime_file('templates/' .. filename, false)
  if #runtime_files > 0 then
    content = utils.read_file(runtime_files[1])
    if content then return trim_trailing(content) end
  end

  return nil
end

-- Replace template variables in content
-- Variables use {{variable_name}} syntax
-- @param template string The template content with {{variable}} placeholders
-- @param vars table Key-value pairs of variables to replace
-- @return string The template with variables replaced
function M.replace_vars(template, vars)
  if not template then return "" end
  local result = template
  for key, value in pairs(vars) do
    local pattern = "{{" .. key .. "}}"
    result = result:gsub(vim.pesc(pattern), tostring(value or ""))
  end
  return result
end

-- Build standard variables table for a shot
-- @param bufnr number|nil Buffer number (0 or nil for current)
-- @param shot_num string|number|nil The shot number
-- @return table Variables table with all standard variables
function M.build_vars(bufnr, shot_num)
  bufnr = bufnr or 0

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local git_root = files.get_git_root()

  return {
    -- Shot variables (prefix: shot_)
    shot_num = shot_num or "",

    -- File variables (prefix: file_)
    file_path = shorten_home(filepath),
    file_name = utils.get_filename(filepath),
    file_title = files.get_file_title(bufnr),

    -- Repository variables (prefix: repo_)
    repo_name = M.get_repo_name(),
    repo_path = shorten_home(git_root or utils.cwd()),
  }
end

-- Build multishot variables (extends standard vars)
-- @param bufnr number|nil Buffer number
-- @param shot_nums table Array of shot numbers
-- @return table Variables table with all variables including shot_nums
function M.build_multishot_vars(bufnr, shot_nums)
  local vars = M.build_vars(bufnr, nil)
  vars.shot_nums = table.concat(shot_nums, ", ")
  return vars
end

-- Load instructions template (single or multishot)
-- @param is_multishot boolean Whether to load multishot template
-- @return string The instructions template content
function M.load_instructions(is_multishot)
  local filename = is_multishot
    and 'shooter-context-instructions-multishot.md'
    or 'shooter-context-instructions.md'

  local content = M.load_template(filename)

  -- Hardcoded fallback if no template found
  if not content then
    if is_multishot then
      content = [[# context
1. These are shots {{shot_nums}} of the feature "{{file_title}}" in repo {{repo_name}}.
2. Please read the file {{file_path}} to get more context on what was prompted before.
3. You should explicitly not implement the old shots.
4. Your current task is to implement all the shots above.
5. Please figure out the best order of implementation.
6. When you have many shots at once, create commits for each of the shots following the repositories git commit conventions.]]
    else
      content = [[# context
1. This is shot {{shot_num}} of the feature "{{file_title}}" in repo {{repo_name}}.
2. Please read the file {{file_path}} to get more context on what was prompted before.
3. You should explicitly not implement the old shots.
4. Your current task is the shot {{shot_num}}.]]
    end
  end

  return content
end

-- Get documentation of all available template variables
-- @return string Markdown documentation of all variables
function M.get_variable_docs()
  return [[## Available Template Variables

### Shot Variables
- `{{shot_num}}` - Current shot number (e.g., "117")
- `{{shot_nums}}` - Comma-separated shot numbers for multishot (e.g., "1, 2, 3")

### File Variables
- `{{file_path}}` - Full absolute path to the file
- `{{file_name}}` - Filename with extension
- `{{file_title}}` - Title from the file's first # heading

### Repository Variables
- `{{repo_name}}` - Repository name from git remote (e.g., "divramod/dev")
- `{{repo_path}}` - Git root path (absolute)
]]
end

return M
