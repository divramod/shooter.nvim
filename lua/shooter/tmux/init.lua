-- Tmux integration module for shooter.nvim
-- Main entry point for tmux functionality

local M = {}

-- Lazy load submodules
M.detect = require('shooter.tmux.detect')
M.send = require('shooter.tmux.send')
M.messages = require('shooter.tmux.messages')

return M
