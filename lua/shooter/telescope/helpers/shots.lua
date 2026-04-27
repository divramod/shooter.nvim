-- Shot detection / entry construction / repo-wide aggregation. Pure parsing
-- on top of helpers.io for line reads.
local M = {}

local utils = require('shooter.utils')
local io_mod = require('shooter.telescope.helpers.io')

function M.find_open_shots(lines)
  local shots = {}
  local i = 1
  while i <= #lines do
    if lines[i]:match('^##%s+shot') and not lines[i]:match('^##%s+x%s+shot') then
      local start_line = i
      local end_line = #lines
      for j = start_line + 1, #lines do
        if lines[j]:match('^##%s+x?%s*shot') then
          end_line = j - 1
          break
        end
      end
      while end_line > start_line and lines[end_line]:match('^%s*$') do
        end_line = end_line - 1
      end
      table.insert(shots, {start_line = start_line, end_line = end_line, header_line = start_line})
      i = end_line + 1
    else
      i = i + 1
    end
  end
  return shots
end

function M.make_shot_entry(shot, lines, target_file, is_current, show_file)
  local shots_mod = require('shooter.core.shots')
  local header = lines[shot.header_line]
  local shot_num = header:match('shot%s+(%d+)') or '?'

  local header_desc = shots_mod.parse_shot_header_text(header)
  local preview
  if header_desc then
    preview = header_desc
  else
    local preview_lines = {}
    for idx = shot.start_line + 1, math.min(shot.start_line + 5, shot.end_line) do
      if lines[idx] and lines[idx] ~= '' then
        table.insert(preview_lines, lines[idx])
        if #preview_lines >= 3 then break end
      end
    end
    preview = table.concat(preview_lines, ' | ')
  end
  if #preview > 60 then preview = preview:sub(1, 60) .. '...' end

  local display
  if show_file then
    local filename = vim.fn.fnamemodify(target_file, ':t:r')
    display = string.format('[%s] Shot %s: %s', filename, shot_num, preview)
  else
    display = string.format('Shot %s: %s', shot_num, preview)
  end

  return {
    shot_num = shot_num, header_line = shot.header_line,
    start_line = shot.start_line, end_line = shot.end_line,
    display = display, lines = lines, target_file = target_file, is_current_file = is_current,
  }
end

function M.get_repo_prompt_files()
  local files_mod = require('shooter.core.files')
  local git_root = files_mod.get_git_root()
  if not git_root then return {} end
  local prompts_dir = git_root .. '/docs/shotfiles'
  if not utils.dir_exists(prompts_dir) then return {} end
  return vim.fn.globpath(prompts_dir, '**/*.md', false, true)
end

function M.get_all_repo_shots()
  local all_shots = {}
  local prompt_files = M.get_repo_prompt_files()

  for _, filepath in ipairs(prompt_files) do
    local lines = io_mod.read_lines(filepath, false)
    if lines then
      local shots = M.find_open_shots(lines)
      for _, shot in ipairs(shots) do
        table.insert(all_shots, M.make_shot_entry(shot, lines, filepath, false, true))
      end
    end
  end

  return all_shots
end

return M
