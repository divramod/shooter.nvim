-- Build shot messages for tmux transmission
-- Construct context-enriched messages for Claude

local utils = require('shooter.utils')
local config = require('shooter.config')
local context = require('shooter.core.context')
local shots = require('shooter.core.shots')
local files = require('shooter.core.files')

local M = {}

-- Trim trailing whitespace (fixes double empty lines)
local function trim_trailing(content)
  if not content then return "" end
  return content:gsub('%s+$', '')
end

-- Load instructions template with priority: project > global > fallback
function M.load_instructions_template(is_multishot)
  local filename = is_multishot and 'shooter-context-instructions-multishot.md'
    or 'shooter-context-instructions.md'

  -- Priority 1: Project-specific (./.shooter.nvim/)
  local git_root = files.get_git_root()
  if git_root then
    local project_path = git_root .. '/.shooter.nvim/' .. filename
    local content = utils.read_file(project_path)
    if content then return trim_trailing(content) end
  end

  -- Priority 2: Global (~/.config/shooter.nvim/)
  local global_path = utils.expand_path('~/.config/shooter.nvim/' .. filename)
  local content = utils.read_file(global_path)
  if content then return trim_trailing(content) end

  -- Fallback: Template from plugin
  local runtime_files = vim.api.nvim_get_runtime_file('templates/' .. filename, false)
  if #runtime_files > 0 then
    content = utils.read_file(runtime_files[1])
    if content then return trim_trailing(content) end
  end

  -- Hardcoded fallback
  if is_multishot then
    return [[# context
1. these are shots {{shots_str}} of the feature "{{title}}".
2. please read the file {{file_path}} to get more context on what was prompted before.
3. you should explicitly not implement the old shots.
4. your current task is to implement all the shots above.
5. please figure out the best order of implementation.
6. when you have many shots at once, create commits for each of the shots following the repositories git commit conventions.]]
  else
    return [[# context
1. this is shot {{shot_num}} of the feature "{{title}}".
2. please read the file {{file_path}} to get more context on what was prompted before.
3. you should explicitly not implement the old shots.
4. your current task is the shot {{shot_num}}.]]
  end
end

-- Replace template variables in message
function M.replace_template_vars(template, vars)
  local result = template
  for key, value in pairs(vars) do
    local pattern = "{{" .. key .. "}}"
    result = result:gsub(vim.pesc(pattern), tostring(value or ""))
  end
  return result
end

-- Format shot content (trim whitespace)
function M.format_shot_content(content)
  if not content or content == "" then return "" end
  return content:match("^%s*(.-)%s*$") or content
end

-- Build context section for message
function M.build_context_section()
  return context.build_context_section()
end

-- Build message for single shot
function M.build_shot_message(bufnr, shot_info)
  bufnr = bufnr or 0

  local shot_content = shots.get_shot_content(bufnr, shot_info.start_line, shot_info.end_line)
  local header_line = shot_info.header_line
  local header_text = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
  local shot_num = shots.parse_shot_header(header_text)

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local title = files.get_file_title(bufnr)

  local ctx = M.build_context_section()
  shot_content = M.format_shot_content(shot_content)

  -- Load and fill instructions template
  local instructions = M.load_instructions_template(false)
  instructions = M.replace_template_vars(instructions, {
    shot_num = shot_num,
    title = title,
    file_path = filepath,
  })

  local message = string.format([[# shot %s (%s)
%s

%s

# Shooter global context (%s)

%s

# Shooter project context (%s)

%s]],
    shot_num,
    title,
    shot_content,
    instructions,
    ctx.global_file,
    trim_trailing(ctx.global_content),
    ctx.project_file,
    trim_trailing(ctx.project_content)
  )

  return message
end

-- Build message for multiple shots
function M.build_multishot_message(bufnr, shot_list)
  bufnr = bufnr or 0

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local title = files.get_file_title(bufnr)
  local ctx = M.build_context_section()

  local shot_parts = {}
  local shot_nums = {}

  for _, shot_info in ipairs(shot_list) do
    local header_text = utils.get_buf_lines(bufnr, shot_info.header_line - 1, shot_info.header_line)[1]
    local shot_num = shots.parse_shot_header(header_text)
    local content = shots.get_shot_content(bufnr, shot_info.start_line, shot_info.end_line)

    table.insert(shot_nums, shot_num)
    table.insert(shot_parts, string.format("## shot %s\n%s", shot_num, content))
  end

  local shots_str = table.concat(shot_nums, ", ")
  local all_shots_content = table.concat(shot_parts, "\n\n")

  -- Load and fill instructions template
  local instructions = M.load_instructions_template(true)
  instructions = M.replace_template_vars(instructions, {
    shots_str = shots_str,
    title = title,
    file_path = filepath,
  })

  local message = string.format([[# shots
%s

%s

# Shooter global context (%s)

%s

# Shooter project context (%s)

%s]],
    all_shots_content,
    instructions,
    ctx.global_file,
    trim_trailing(ctx.global_content),
    ctx.project_file,
    trim_trailing(ctx.project_content)
  )

  return message
end

-- Get shot message stats (for display purposes)
function M.get_message_stats(message)
  local char_count = #message
  local line_count = select(2, message:gsub('\n', '\n')) + 1

  return {
    chars = char_count,
    lines = line_count,
    is_long = line_count > 50 or char_count > 5000
  }
end

return M
