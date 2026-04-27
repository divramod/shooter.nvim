-- Root-table tmux keybinding installer (opt+shift+A / M-A) for hide+menu.
-- Pulled out of shooter/tmux/toggle_panes.lua during plan 0001 phase 004 T007.

local exec = require('shooter.tmux.toggle_panes.exec')
local detect = require('shooter.tmux.detect')
local hidden_session = require('shooter.tmux.hidden_session')

local M = {}

function M.setup_tmux_keybinding()
  if not detect.check_tmux_installed() or not detect.in_tmux() then
    return
  end

  local session_name = hidden_session.get_session_name()

  -- Remove old keybindings from previous versions
  exec.tmux_run("tmux unbind-key H 2>/dev/null")
  exec.tmux_run("tmux unbind-key -n M-H 2>/dev/null")

  local keybind_cmd = string.format([[tmux bind-key -n M-A run-shell '
    PANE_ID=$(tmux display -p "#{pane_id}" | tr -d "%%")
    PANE_CMD=$(tmux display -p "#{pane_current_command}")
    NAME_FILE="/tmp/shooter-pane-$PANE_ID"

    if [ -f "$NAME_FILE" ]; then
      NAME=$(cat "$NAME_FILE")
      FOLDER_FILE="/tmp/shooter-folder-$PANE_ID"
      if [ -f "$FOLDER_FILE" ]; then
        FOLDER=$(cat "$FOLDER_FILE")
      else
        FOLDER=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
      fi
      WINDOW_NAME="$FOLDER-$NAME"
      tmux has-session -t "%s" 2>/dev/null || tmux new-session -d -s "%s" -n "placeholder"
      tmux break-pane -d -t "%s:" -n "$WINDOW_NAME"
    elif [ "$PANE_CMD" = "nvim" ] || [ "$PANE_CMD" = "vim" ]; then
      tmux send-keys -t "%%$PANE_ID" Escape ":ShoTmuxTogglePanes" Enter
    fi
  ']], session_name, session_name, session_name)
  exec.tmux_run(keybind_cmd)
end

return M
