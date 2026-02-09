-- View response for a sent shot (Claude or OpenCode)

local utils = require('shooter.utils')
local shots = require('shooter.core.shots')
local claude = require('shooter.tools.response_viewer.claude')
local opencode = require('shooter.tools.response_viewer.opencode')

local M = {}

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

local function format_response_text(response_text, tool_calls)
  tool_calls = tool_calls or {}
  if response_text and #tool_calls > 0 then
    local trimmed = response_text:gsub('^%s*', ''):gsub('%s*$', '')
    if trimmed:match('^```') and trimmed:match('```%s*$') then
      response_text = response_text .. '\n---\n\n**Tool calls performed:**\n'
      for _, tool in ipairs(tool_calls) do
        response_text = response_text .. '- ' .. tool .. '\n'
      end
      response_text = response_text .. '\n*Note: Response may have been truncated due to context compaction.*\n'
    end
  elseif (not response_text or response_text == '') and #tool_calls > 0 then
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

  -- Check for @ref in header (supports both old and new naming)
  -- New: @cfg_20260209_074209_shot-58   Old: @shot-1-20260204_083659
  local temp_ref = header:match('@([%w%.%-_]+_shot%-[%d%-]+)') or header:match('@(shot%-[%d_%-]+)')
  local shot_pattern

  if temp_ref then
    -- Use direct reference (reliable)
    shot_pattern = temp_ref:gsub('%-', '%%-'):gsub('%.', '%%.')
  else
    -- Fallback: try timestamp-based lookup (oldest shots without @ref)
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

  local response_text, tool_calls = opencode.find_response(shot_pattern)
  if not response_text and (not tool_calls or #tool_calls == 0) then
    response_text, tool_calls = claude.find_response(shot_pattern)
  end

  response_text = format_response_text(response_text, tool_calls)

  if not response_text then
    utils.echo('No response found for shot ' .. shot_num)
    return
  end

  -- Display in a new buffer
  local resp_bufnr = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(response_text, '\n')
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
