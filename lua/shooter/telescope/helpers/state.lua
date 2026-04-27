-- Persistent shot-picker selection / cursor state. Reads from and writes to
-- helpers.init's shared `persistent_state` singleton via the registry
-- functions exported below.
local M = {}

local action_state = require('telescope.actions.state')

-- The shared store lives on helpers/init to keep a single source of truth
-- across modules. Lazily resolved here to avoid require-cycle risk.
local function store()
  return require('shooter.telescope.helpers').persistent_state
end

function M.clear_selection(filepath)
  local s = store()
  if filepath then
    s[filepath] = nil
  else
    -- Drain in place rather than reassigning so external `helpers.persistent_state`
    -- references remain valid.
    for k in pairs(s) do s[k] = nil end
  end
end

function M.save_selection_state(prompt_bufnr, target_file)
  local picker = action_state.get_current_picker(prompt_bufnr)
  local multi = picker:get_multi_selection()
  local selected_shots = {}
  for _, entry in ipairs(multi) do
    if entry.value and entry.value.shot_num then
      selected_shots[entry.value.shot_num] = true
    end
  end
  store()[target_file] = {
    selections = selected_shots,
    cursor_row = picker:get_selection_row(),
  }
end

function M.restore_selection_state(prompt_bufnr, target_file, retry_count)
  retry_count = retry_count or 0
  local max_retries = 10

  local state = store()[target_file]
  if not state then return end

  local saved = state.selections
  local saved_cursor = state.cursor_row

  local picker = action_state.get_current_picker(prompt_bufnr)
  if not picker or not picker._multi then
    if retry_count < max_retries then
      vim.defer_fn(function()
        M.restore_selection_state(prompt_bufnr, target_file, retry_count + 1)
      end, 50)
    end
    return
  end

  local manager = picker.manager
  if not manager or type(manager) ~= 'table' then
    if retry_count < max_retries then
      vim.defer_fn(function()
        M.restore_selection_state(prompt_bufnr, target_file, retry_count + 1)
      end, 50)
    end
    return
  end

  local has_entries = false
  for _ in manager:iter() do
    has_entries = true
    break
  end
  if not has_entries and retry_count < max_retries then
    vim.defer_fn(function()
      M.restore_selection_state(prompt_bufnr, target_file, retry_count + 1)
    end, 50)
    return
  end

  local rows_to_select = {}
  if saved and not vim.tbl_isempty(saved) then
    local row = 0
    for entry in manager:iter() do
      if entry.value and entry.value.shot_num and saved[entry.value.shot_num] then
        table.insert(rows_to_select, row)
      end
      row = row + 1
    end
  end

  if #rows_to_select > 0 then
    local actions = require('telescope.actions')
    for _, target_row in ipairs(rows_to_select) do
      picker:set_selection(target_row)
      actions.toggle_selection(prompt_bufnr)
    end
  end

  if saved_cursor then
    picker:set_selection(saved_cursor)
  end
end

return M
