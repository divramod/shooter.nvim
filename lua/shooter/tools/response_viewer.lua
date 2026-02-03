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

-- Find assistant response by tracking parentUuid chain from user message
local function find_response_in_jsonl(jsonl_path, shot_pattern)
  local file = io.open(jsonl_path, 'r')
  if not file then return nil end

  -- First pass: find user message UUID and collect all entries
  local user_uuid = nil
  local entries = {}
  for line in file:lines() do
    local ok, data = pcall(vim.fn.json_decode, line)
    if ok and data then
      table.insert(entries, data)
      if not user_uuid and data.type == 'user' and data.message and data.message.content then
        local content = data.message.content
        local content_str = type(content) == 'string' and content or vim.fn.json_encode(content)
        if content_str:match(shot_pattern) then
          user_uuid = data.uuid
        end
      end
    end
  end
  file:close()
  if not user_uuid then return nil end

  -- Build set of related UUIDs (user message and all its descendants)
  local related = { [user_uuid] = true }
  for _ = 1, 20 do -- Max depth to prevent infinite loops
    local added = false
    for _, entry in ipairs(entries) do
      if entry.parentUuid and type(entry.parentUuid) == 'string' and related[entry.parentUuid] and entry.uuid and type(entry.uuid) == 'string' and not related[entry.uuid] then
        related[entry.uuid] = true
        added = true
      end
    end
    if not added then break end
  end

  -- Collect text and tool calls from related assistant messages
  local response_text = nil
  local tool_calls = {}
  for _, entry in ipairs(entries) do
    if entry.uuid and type(entry.uuid) == 'string' and related[entry.uuid] and entry.message and entry.message.role == 'assistant' then
      local content = entry.message.content
      if type(content) == 'table' then
        for _, block in ipairs(content) do
          if block.type == 'text' and block.text then
            response_text = (response_text or '') .. block.text .. '\n'
          elseif block.type == 'tool_use' and block.name then
            table.insert(tool_calls, block.name)
          end
        end
      elseif type(content) == 'string' then
        response_text = (response_text or '') .. content .. '\n'
      end
    end
  end

  -- If we only have the echo (code block) and tool calls, create a summary
  if response_text and #tool_calls > 0 then
    -- Check if response_text is just a code block (echo)
    local trimmed = response_text:gsub('^%s*', ''):gsub('%s*$', '')
    if trimmed:match('^```') and trimmed:match('```%s*$') then
      -- Response is only the echo, add tool summary
      response_text = response_text .. '\n---\n\n**Tool calls performed:**\n'
      for _, tool in ipairs(tool_calls) do
        response_text = response_text .. '- ' .. tool .. '\n'
      end
      response_text = response_text .. '\n*Note: Response may have been truncated due to context compaction.*\n'
    end
  elseif not response_text and #tool_calls > 0 then
    -- No text at all, just tool calls
    response_text = '**Tool calls performed:**\n'
    for _, tool in ipairs(tool_calls) do
      response_text = response_text .. '- ' .. tool .. '\n'
    end
    response_text = response_text .. '\n*Note: Response may have been truncated due to context compaction.*\n'
  end

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

  -- Open in horizontal split below, 80% height
  vim.cmd('belowright split')
  vim.api.nvim_set_current_buf(resp_bufnr)
  local total_height = vim.o.lines - vim.o.cmdheight - 1
  vim.api.nvim_win_set_height(0, math.floor(total_height * 0.8))
  utils.echo('Response for shot ' .. shot_num)
end

return M
