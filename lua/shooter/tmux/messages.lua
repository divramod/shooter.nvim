-- Build shot messages for tmux transmission
-- Construct context-enriched messages for Claude

local utils = require('shooter.utils')
local config = require('shooter.config')
local context = require('shooter.core.context')
local shots = require('shooter.core.shots')
local files = require('shooter.core.files')

local M = {}

-- Read message template from config or use fallback
function M.read_message_template()
  return context.read_message_template()
end

-- Format shot content (trim whitespace)
function M.format_shot_content(content)
  if not content or content == "" then
    return ""
  end
  return content:match("^%s*(.-)%s*$") or content
end

-- Build context section for message
function M.build_context_section()
  return context.build_context_section()
end

-- Replace template variables in message
function M.replace_template_vars(template, vars)
  local result = template

  for key, value in pairs(vars) do
    local pattern = "{{" .. key .. "}}"
    result = result:gsub(vim.pesc(pattern), value or "")
  end

  return result
end

-- Build message for single shot
function M.build_shot_message(bufnr, shot_info)
  bufnr = bufnr or 0

  -- Extract shot information
  local shot_content = shots.get_shot_content(bufnr, shot_info.start_line, shot_info.end_line)
  local header_line = shot_info.header_line
  local header_text = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
  local shot_num = shots.parse_shot_header(header_text)

  -- Get file information
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local title = files.get_file_title(bufnr)

  -- Build context
  local ctx = M.build_context_section()

  -- Format shot content
  shot_content = M.format_shot_content(shot_content)

  -- Build message using template
  local message = string.format([[# shot %s (%s)
%s

# context
1. this is shot %s of the feature "%s".
2. please read the file %s to get more context on what was prompted before.
3. you should explicitly not implement the old shots.
4. your current task is the shot %s.

# Shooter general context (%s)

%s

# Shooter project context (%s)

%s]],
    shot_num,
    title,
    shot_content,
    shot_num,
    title,
    filepath,
    shot_num,
    ctx.general_file,
    ctx.general_content,
    ctx.project_file,
    ctx.project_content
  )

  return message
end

-- Build message for multiple shots
function M.build_multishot_message(bufnr, shot_list)
  bufnr = bufnr or 0

  -- Get file information
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local title = files.get_file_title(bufnr)

  -- Build context
  local ctx = M.build_context_section()

  -- Build shot parts
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

  -- Build multishot message
  local message = string.format([[# shots
%s

# context
1. these are shots %s of the feature "%s".
2. please read the file %s to get more context on what was prompted before.
3. you should explicitly not implement the old shots.
4. your current task is to implement all the shots above.
5. please figure out the best order of implementation.
6. when you have many shots at once, create commits for each of the shots following the repositories git commit conventions.

# Shooter general context (%s)

%s

# Shooter project context (%s)

%s]],
    all_shots_content,
    shots_str,
    title,
    filepath,
    ctx.general_file,
    ctx.general_content,
    ctx.project_file,
    ctx.project_content
  )

  return message
end

-- Build message from template (future enhancement)
function M.build_from_template(template_vars)
  local template = M.read_message_template()
  return M.replace_template_vars(template, template_vars)
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
