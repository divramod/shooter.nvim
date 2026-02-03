-- View Claude's response for a sent shot
-- Searches JSONL session files to find the response matching a shot's timestamp

local utils = require('shooter.utils')
local shots = require('shooter.core.shots')

local M = {}

-- Get Claude projects directory for current repo
-- Claude escapes: / -> -, . -> - (keeps leading dash)
local function get_claude_projects_dir()
  local cwd = vim.fn.getcwd()
  local escaped = cwd:gsub('/', '-'):gsub('%.', '-')
  return utils.expand_path('~/.claude/projects/' .. escaped)
end

-- Parse timestamp from shot header to match temp file format
-- Header: (2026-02-03 08:50:18) -> 20260203_085018
local function header_ts_to_file_ts(header_ts)
  if not header_ts then return nil end
  -- "2026-02-03 08:50:18" -> "20260203_085018"
  local date, time = header_ts:match('(%d%d%d%d%-%d%d%-%d%d)%s+(%d%d:%d%d:%d%d)')
  if not date or not time then return nil end
  local file_date = date:gsub('-', '')
  local file_time = time:gsub(':', '')
  return file_date .. '_' .. file_time
end

-- Find assistant response after a user message in JSONL
local function find_response_in_jsonl(jsonl_path, shot_pattern)
  local file = io.open(jsonl_path, 'r')
  if not file then return nil end

  local found_user_msg = false
  local response_text = nil

  for line in file:lines() do
    local ok, data = pcall(vim.fn.json_decode, line)
    if ok and data then
      if not found_user_msg then
        -- Look for user message containing our shot file
        if data.type == 'user' and data.message and data.message.content then
          local content = data.message.content
          local content_str = type(content) == 'string' and content or vim.fn.json_encode(content)
          if content_str:match(shot_pattern) then
            found_user_msg = true
          end
        end
      else
        -- After finding user message, collect text from assistant responses
        if data.message and data.message.role == 'assistant' then
          local content = data.message.content
          if type(content) == 'table' then
            for _, block in ipairs(content) do
              if block.type == 'text' and block.text then
                response_text = (response_text or '') .. block.text .. '\n'
              end
            end
          elseif type(content) == 'string' then
            response_text = (response_text or '') .. content .. '\n'
          end
        -- Stop when we hit next user message (response complete)
        elseif data.type == 'user' then
          break
        end
      end
    end
  end

  file:close()
  return response_text
end

-- View response for shot under cursor
function M.view_response()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = utils.get_cursor()[1]
  local shot_start, _, header_line = shots.find_current_shot(bufnr, cursor_line)

  if not shot_start then
    utils.echo('No shot found under cursor')
    return
  end

  local header = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
  local shot_num = shots.parse_shot_header(header)

  -- Check for @ref in header (new format with direct temp file reference)
  local temp_ref = header:match('@(shot%-[%d_%-]+)')
  local shot_pattern

  if temp_ref then
    -- Use direct reference (reliable)
    shot_pattern = temp_ref:gsub('%-', '%%-')
  else
    -- Fallback: try timestamp-based lookup (older shots)
    local header_ts = header:match('%((%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)%)')
    if not header_ts then
      utils.echo('Shot ' .. shot_num .. ' has not been sent yet')
      return
    end
    local file_ts = header_ts_to_file_ts(header_ts)
    if not file_ts then
      utils.echo('Could not parse timestamp from shot header')
      return
    end
    shot_pattern = 'shot%-' .. shot_num .. '%-' .. file_ts
  end

  -- Find JSONL files in Claude projects dir
  local projects_dir = get_claude_projects_dir()
  local jsonl_files = vim.fn.glob(projects_dir .. '/*.jsonl', false, true)

  if #jsonl_files == 0 then
    utils.echo('No Claude session files found for this project')
    return
  end

  -- Search newest files first
  table.sort(jsonl_files, function(a, b)
    return vim.fn.getftime(a) > vim.fn.getftime(b)
  end)

  local response = nil
  for _, jsonl_path in ipairs(jsonl_files) do
    response = find_response_in_jsonl(jsonl_path, shot_pattern)
    if response then break end
  end

  if not response then
    utils.echo('No response found for shot ' .. shot_num)
    return
  end

  -- Display in a new buffer
  local resp_bufnr = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(response, '\n')
  vim.api.nvim_buf_set_lines(resp_bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(resp_bufnr, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(resp_bufnr, 'buftype', 'nofile')
  vim.api.nvim_buf_set_name(resp_bufnr, 'Shot ' .. shot_num .. ' Response')

  -- Open in split
  vim.cmd('vsplit')
  vim.api.nvim_set_current_buf(resp_bufnr)
  utils.echo('Response for shot ' .. shot_num)
end

return M
