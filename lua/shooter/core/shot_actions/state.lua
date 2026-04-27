-- Shot state mutation: toggle done, undo latest sent.

local utils = require('shooter.utils')
local shots = require('shooter.core.shots')

local M = {}

-- Toggle shot done status (mark/unmark with x and timestamp).
function M.toggle_shot_done()
  local bufnr = 0
  local cursor_line = utils.get_cursor()[1]

  local shot_start, shot_end, header_line = shots.find_current_shot(bufnr, cursor_line)
  if not shot_start then
    utils.echo('Not in a shot')
    return
  end

  local line = utils.get_buf_lines(bufnr, header_line - 1, header_line)[1]
  local shot_num = shots.parse_shot_header(line)

  local config = require('shooter.config')
  local is_done = line:match(config.get('patterns.executed_shot_header')) ~= nil

  if is_done then
    -- Pattern: ## x shot N (date) @shot-N-... → ## shot N
    line = line:gsub('^(##)%s+x%s+shot', '%1 shot')
    line = line:gsub('%s*%(%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d%)', '')
    line = line:gsub('%s*@[%w%.%-_]+', '')
    line = line:gsub('%s+$', '')
    utils.set_buf_lines(bufnr, header_line - 1, header_line, { line })
    utils.echo('Shot ' .. shot_num .. ' marked open')
  else
    local timestamp = utils.get_timestamp()
    line = line:gsub('^(##)%s+shot', '%1 x shot')
    line = line .. ' (' .. timestamp .. ')'
    utils.set_buf_lines(bufnr, header_line - 1, header_line, { line })
    utils.echo('Shot ' .. shot_num .. ' marked done')
  end

  -- Renumber + resort (open shots top, done shots bottom).
  local renumber_helper = require('shooter.tmux.renumber_helper')
  local new_start, _, new_header = renumber_helper.renumber_and_find_shot(bufnr, shot_start, shot_end)
  if new_header then
    vim.api.nvim_win_set_cursor(0, { new_header, 0 })
  end
end

-- Undo the marking of the latest sent shot (## x shot ... → ## shot ...).
function M.undo_latest_sent_shot()
  local bufnr = 0
  local config = require('shooter.config')
  local lines = utils.get_buf_lines(bufnr, 0, -1)

  local latest_line = nil
  local latest_timestamp = nil

  for i, line in ipairs(lines) do
    if line:match(config.get('patterns.executed_shot_header')) then
      local timestamp = line:match('%((%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)%)')
      if timestamp then
        if not latest_timestamp or timestamp > latest_timestamp then
          latest_timestamp = timestamp
          latest_line = i
        end
      end
    end
  end

  if not latest_line then
    utils.echo('No sent shots found to undo')
    return
  end

  local line = lines[latest_line]
  local shot_num = shots.parse_shot_header(line)

  -- Pattern: ## x shot N (date) @shot-N-... → ## shot N
  line = line:gsub('^(##)%s+x%s+shot', '%1 shot')
  line = line:gsub('%s*%(%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d%)', '')
  line = line:gsub('%s*@shot%-[%d_%-]+', '')
  line = line:gsub('%s+$', '')
  utils.set_buf_lines(bufnr, latest_line - 1, latest_line, { line })

  vim.api.nvim_win_set_cursor(0, { latest_line, 0 })

  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname ~= '' then
    vim.cmd('silent! write')
  end

  utils.echo('Undone marking: Shot ' .. shot_num .. ' is now open')
end

return M
