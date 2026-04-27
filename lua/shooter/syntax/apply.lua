-- Extmark-based syntax engine. Walks a shotfile buffer and places highlight
-- extmarks for open / executed / day-marker shot headers + markdown links.
-- Pulled out of shooter/syntax.lua during plan 0001 phase 004 T005.

local detect = require('shooter.syntax.detect')

local M = {}

local ns = vim.api.nvim_create_namespace('shooter_syntax')

-- Day-marker coloring toggle (enabled by default; module-local state)
local day_marker_enabled = true

function M.apply_syntax(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local config = require('shooter.config')
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local in_code = detect.build_code_block_map(lines)

  local latest_done_line = nil
  local latest_timestamp = nil
  local exec_pattern = config.get('patterns.executed_shot_header')

  local day_first_lines = {}
  local seen_days = {}

  for i, line in ipairs(lines) do
    if not in_code[i] and line:match(exec_pattern) then
      local ts = line:match('%((%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d)%)')
      if ts and (not latest_timestamp or ts > latest_timestamp) then
        latest_timestamp = ts
        latest_done_line = i
      end
      if day_marker_enabled then
        local date = line:match('%((%d%d%d%d%-%d%d%-%d%d)%s+%d%d:%d%d:%d%d%)')
        if date then
          seen_days[date] = i
        end
      end
    end
  end

  for _, line_num in pairs(seen_days) do
    day_first_lines[line_num] = true
  end

  local matches = {}
  for i, line in ipairs(lines) do
    if not in_code[i] then
      if i == latest_done_line or day_first_lines[i] then
        local prefix_group = i == latest_done_line and 'HalShooterDoneShotPrefix' or 'HalShooterDayMarkerPrefix'
        local title_group = i == latest_done_line and 'HalShooterDoneShotTitle' or 'HalShooterDayMarkerTitle'
        local postfix_group = i == latest_done_line and 'HalShooterDoneShotPostfix' or 'HalShooterDayMarkerPostfix'
        local number_end, title_start, title_end = detect.split_executed_header(line)
        if number_end and title_start then
          table.insert(matches, { i, prefix_group, 0, title_start - 1 })
          table.insert(matches, { i, title_group, title_start - 1, title_end })
          table.insert(matches, { i, postfix_group, title_end, #line })
        else
          table.insert(matches, { i, prefix_group })
        end
      elseif line:match('^##%s+shot%s+[%d%?]+') then
        local _, number_end_pos = line:find('^##%s+shot%s+[%d%?]+')
        local title_start = line:find('%S', number_end_pos + 1)
        if title_start then
          table.insert(matches, { i, 'HalShooterOpenShot', 0, title_start - 1 })
          table.insert(matches, { i, 'HalShooterOpenShotTitle', title_start - 1, #line })
        else
          table.insert(matches, { i, 'HalShooterOpenShot' })
        end
      else
        local md_links = require('shooter.markdown_links')
        for _, r in ipairs(md_links.find_ranges(line)) do
          table.insert(matches, { i, 'HalShooterMdLink', r[1], r[2] })
        end
      end
    end
  end

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  for _, m in ipairs(matches) do
    if m[3] then
      vim.api.nvim_buf_set_extmark(bufnr, ns, m[1] - 1, m[3], {
        end_col = m[4],
        hl_group = m[2],
      })
    else
      vim.api.nvim_buf_set_extmark(bufnr, ns, m[1] - 1, 0, {
        end_col = #lines[m[1]],
        hl_group = m[2],
      })
    end
  end
end

-- Toggle day marker coloring on/off; reapply if current buffer is a shotfile.
function M.toggle_day_marker()
  day_marker_enabled = not day_marker_enabled
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if detect.is_prompts_file(filepath) then
    M.apply_syntax(bufnr)
  end
end

return M
