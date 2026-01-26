-- Audit runner - runs audit in subprocess for truly non-blocking operation
-- Spawns nvim --headless to do the work, reads results when done

local utils = require('shooter.utils')

local M = {}

M._last_report = nil
M._job_id = nil

function M.get_reports_dir()
  return utils.expand_path('~/.config/shooter.nvim/audit-reports')
end

function M.generate_report_path()
  local dir = M.get_reports_dir()
  utils.ensure_dir(dir)
  return dir .. '/audit-' .. os.date('%Y%m%d_%H%M%S') .. '.md'
end

-- Get plugin root path dynamically
local function get_plugin_root()
  local info = debug.getinfo(1, 'S')
  local path = info.source:sub(2) -- remove leading @
  return path:match('(.*/shooter%.nvim)') or vim.fn.fnamemodify(path, ':h:h:h:h')
end

-- Build the Lua code to run in subprocess
local function build_audit_script(do_fix, result_file, plugin_root, files_json)
  return string.format([[
    vim.opt.runtimepath:prepend('%s')
    local audit = require('shooter.history.audit')
    local utils = require('shooter.utils')
    local files = vim.json.decode('%s')
    local results = { files_checked = 0, dates_fixed = 0, history_created = 0, history_files = 0, details = {} }
    -- Count history files
    local history_dir = utils.expand_path('~/.config/shooter.nvim/history')
    local count_cmd = 'find "' .. history_dir .. '" -name "shot-*.md" -type f 2>/dev/null | wc -l'
    local count_result = utils.system(count_cmd)
    results.history_files = tonumber(utils.trim(count_result or '0')) or 0
    for _, filepath in ipairs(files) do
      local detail = { file = filepath, dates_fixed = 0, history_missing = 0 }
      detail.dates_fixed = audit.fix_shots_missing_dates(filepath, %s)
      for _, shot_data in ipairs(audit.find_missing_history(filepath)) do
        if %s then
          if audit.create_history_file(shot_data) then detail.history_missing = detail.history_missing + 1 end
        else
          detail.history_missing = detail.history_missing + 1
        end
      end
      results.files_checked = results.files_checked + 1
      results.dates_fixed = results.dates_fixed + detail.dates_fixed
      results.history_created = results.history_created + detail.history_missing
      if detail.dates_fixed > 0 or detail.history_missing > 0 then
        table.insert(results.details, detail)
      end
    end
    local f = io.open('%s', 'w')
    f:write(vim.json.encode(results))
    f:close()
  ]], plugin_root, files_json:gsub("'", "\\'"), tostring(do_fix), tostring(do_fix), result_file)
end

function M.generate_report(results, do_fix)
  local lines = {
    '# Shooter History Audit Report', '',
    '**Date:** ' .. os.date('%Y-%m-%d %H:%M:%S'),
    '**Mode:** ' .. (do_fix and 'Fix' or 'Report only'), '',
    '## Summary', '',
    '| Metric | Count |', '|--------|-------|',
    '| Prompt files checked | ' .. results.files_checked .. ' |',
    '| History files | ' .. (results.history_files or 0) .. ' |',
    '| Shots missing dates | ' .. results.dates_fixed .. ' |',
    '| Missing history entries | ' .. results.history_created .. ' |', '',
  }
  if #results.details > 0 then
    table.insert(lines, '## Details')
    table.insert(lines, '')
    for _, d in ipairs(results.details) do
      table.insert(lines, '### ' .. d.file)
      table.insert(lines, '')
      if d.dates_fixed > 0 then
        table.insert(lines, '- ' .. (do_fix and 'Fixed' or 'Found') .. ' ' .. d.dates_fixed .. ' shots missing dates')
      end
      if d.history_missing > 0 then
        table.insert(lines, '- ' .. (do_fix and 'Created' or 'Found') .. ' ' .. d.history_missing .. ' missing history entries')
      end
      table.insert(lines, '')
    end
  else
    vim.list_extend(lines, { '## Details', '', 'No issues found.', '' })
  end
  return table.concat(lines, '\n')
end

-- Run audit in subprocess - truly non-blocking
function M.run_async(opts)
  opts = opts or {}
  local do_fix = opts.fix or false

  if M._job_id then
    utils.notify('HistoryAudit: Already running', vim.log.levels.WARN)
    return
  end

  -- Get file list in parent process (where config is available)
  local audit = require('shooter.history.audit')
  local files = audit.get_all_repos_prompt_files()
  if #files == 0 then
    utils.notify('HistoryAudit: No files to audit', vim.log.levels.WARN)
    return
  end

  local result_file = vim.fn.tempname() .. '.json'
  local plugin_root = get_plugin_root()
  local files_json = vim.json.encode(files)
  local script = build_audit_script(do_fix, result_file, plugin_root, files_json)
  local cmd = { 'nvim', '--headless', '--clean', '-l', '/dev/stdin' }

  utils.notify('HistoryAudit: Running in background (' .. #files .. ' files)...', vim.log.levels.INFO)

  M._job_id = vim.fn.jobstart(cmd, {
    stdin = 'pipe',
    on_exit = function(_, exit_code)
      M._job_id = nil
      vim.schedule(function()
        if exit_code ~= 0 then
          utils.notify('HistoryAudit: Failed (exit ' .. exit_code .. ')', vim.log.levels.ERROR)
          return
        end
        M.on_complete(result_file, do_fix)
      end)
    end,
  })

  if M._job_id <= 0 then
    utils.notify('HistoryAudit: Failed to start', vim.log.levels.ERROR)
    M._job_id = nil
    return
  end

  vim.fn.chansend(M._job_id, script)
  vim.fn.chanclose(M._job_id, 'stdin')
end

function M.on_complete(result_file, do_fix)
  local content = utils.read_file(result_file)
  os.remove(result_file)

  if not content then
    utils.notify('HistoryAudit: No results', vim.log.levels.ERROR)
    return
  end

  local ok, results = pcall(vim.json.decode, content)
  if not ok then
    utils.notify('HistoryAudit: Invalid results', vim.log.levels.ERROR)
    return
  end

  local report_path = M.generate_report_path()
  if not utils.write_file(report_path, M.generate_report(results, do_fix)) then
    utils.notify('HistoryAudit: Failed to write report', vim.log.levels.ERROR)
    return
  end

  M._last_report = report_path
  local msg = string.format('HistoryAudit done: %d files, %d dates, %d history. Open report?',
    results.files_checked, results.dates_fixed, results.history_created)

  local choice = vim.fn.confirm(msg, '&Yes\n&No', 2)
  if choice == 1 then
    vim.cmd('edit ' .. utils.fnameescape(M._last_report))
  end
end

function M.open_last_report()
  if M._last_report and utils.file_exists(M._last_report) then
    vim.cmd('edit ' .. utils.fnameescape(M._last_report))
  else
    utils.notify('No recent audit report', vim.log.levels.WARN)
  end
end

return M
