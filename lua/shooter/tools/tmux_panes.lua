-- Thin wrapper around `tmux list-panes` / `tmux capture-pane` used by the
-- link picker so it can surface links from neighbour panes.
local M = {}

local function run(cmd)
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then return nil, table.concat(out, '\n') end
  return out, nil
end

-- Return true if we appear to be running inside a tmux session.
function M.in_tmux()
  return (os.getenv('TMUX') or '') ~= ''
end

-- List panes in the current window. Each entry: { id, title, pid, active }.
-- `id` is the `%N` pane id; `title` is #{pane_title} (falling back to the
-- command when empty).
function M.list_current_window()
  if not M.in_tmux() then return {}, 'not in tmux' end
  local fmt = "#{pane_id}\t#{pane_title}\t#{pane_current_command}\t#{pane_active}"
  local lines, err = run({ 'tmux', 'list-panes', '-F', fmt })
  if not lines then return {}, err end
  local out = {}
  for _, line in ipairs(lines) do
    local id, title, cmd, active = line:match('^(%S+)\t(.-)\t(.-)\t(%d+)$')
    if id then
      if title == '' or title == nil then title = cmd end
      table.insert(out, {
        id = id,
        title = title,
        command = cmd,
        active = active == '1',
      })
    end
  end
  return out, nil
end

-- Capture the visible contents of a pane as an array of lines.
function M.capture(pane_id)
  local lines, err = run({ 'tmux', 'capture-pane', '-p', '-J', '-t', pane_id })
  if not lines then return nil, err end
  return lines, nil
end

return M
