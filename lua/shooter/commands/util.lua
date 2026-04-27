-- Shared helpers used by every commands/* sub-area registration block.

local M = {}

-- Wrap fn so it only runs in shotfiles (docs/shotfiles).
function M.require_shotfile(fn)
  return function(opts)
    local files = require('shooter.core.files')
    if not files.is_shooter_file() then
      return
    end
    fn(opts)
  end
end

-- Thin alias over nvim_create_user_command so call sites stay terse.
function M.create_cmd(name, fn, opts)
  vim.api.nvim_create_user_command(name, fn, opts)
end

return M
