-- Build shot messages for tmux transmission
-- Construct context-enriched messages for Claude

local utils = require('shooter.utils')
local context = require('shooter.core.context')
local shots = require('shooter.core.shots')
local files = require('shooter.core.files')
local templates = require('shooter.core.templates')

local M = {}

-- Trim trailing whitespace (fixes double empty lines)
local function trim_trailing(content)
  if not content then return "" end
  return content:gsub('%s+$', '')
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

  local ctx = M.build_context_section()
  shot_content = M.format_shot_content(shot_content)

  -- Build variables and load instructions template
  local vars = templates.build_vars(bufnr, shot_num)
  local instructions = templates.load_instructions(false)
  instructions = templates.replace_vars(instructions, vars)

  local message = string.format([[# shot %s (%s)
%s

%s

# Shooter global context (%s)

%s

# Shooter project context (%s)

%s]],
    shot_num,
    vars.file_title,
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

  local all_shots_content = table.concat(shot_parts, "\n\n")

  -- Build variables and load instructions template
  local vars = templates.build_multishot_vars(bufnr, shot_nums)
  local instructions = templates.load_instructions(true)
  instructions = templates.replace_vars(instructions, vars)

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
