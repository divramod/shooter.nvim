-- Tool namespace commands (l prefix in keymaps).

local util = require('shooter.commands.util')
local create_cmd = util.create_cmd

local M = {}

function M.setup()
  create_cmd('HalShooterToolToken', function()
    require('shooter.tools.token_counter').show_token_count()
  end, { desc = 'Count tokens' })

  create_cmd('HalShooterToolObsidian', function()
    require('shooter.tools.obsidian').open_in_obsidian()
  end, { desc = 'Open in Obsidian' })

  create_cmd('HalShooterToolImages', function()
    require('shooter.images').insert_images()
  end, { desc = 'Insert images' })

  create_cmd('HalShooterToolPrd', function()
    require('shooter.prd').list()
  end, { desc = 'PRD list' })

  create_cmd('HalShooterToolGreenkeep', function()
    require('shooter.core.greenkeep').run()
  end, { desc = 'Convert old date formats' })

  create_cmd('HalShooterToolSoundTest', function()
    require('shooter.sound').test()
  end, { desc = 'Test sound' })

  create_cmd('HalShooterToolClipboardPaste', function()
    require('shooter.tools.clipboard_image').paste_image_normal()
  end, { desc = 'Paste clipboard image' })

  create_cmd('HalShooterToolClipboardCheck', function()
    require('shooter.tools.clipboard_image').check()
  end, { desc = 'Check clipboard for image' })

  create_cmd('HalShooterToolClipboardImages', function()
    require('shooter.tools.clipboard_image').open_images_dir()
  end, { desc = 'Open clipboard images folder' })
end

return M
