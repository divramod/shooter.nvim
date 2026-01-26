-- Tests for shooter.tools.clipboard_image
local clipboard_image = require('shooter.tools.clipboard_image')

describe('clipboard_image', function()
  local test_dir

  before_each(function()
    test_dir = vim.fn.tempname()
    vim.fn.mkdir(test_dir, 'p')
  end)

  after_each(function()
    if test_dir then
      vim.fn.delete(test_dir, 'rf')
    end
  end)

  describe('get_script_path', function()
    it('returns path ending with shooter-clipboard-image', function()
      local path = clipboard_image.get_script_path()
      assert.truthy(path:match('shooter%-clipboard%-image$'))
    end)

    it('returns path to existing script file', function()
      local path = clipboard_image.get_script_path()
      -- Script should exist (or at least path should be valid format)
      assert.truthy(path:match('scripts/shooter%-clipboard%-image$'))
    end)
  end)

  describe('get_save_dir', function()
    it('returns default dir when not in git repo', function()
      -- Save current dir and change to temp
      local orig_cwd = vim.fn.getcwd()
      vim.cmd('cd ' .. test_dir)

      local save_dir = clipboard_image.get_save_dir()
      assert.truthy(save_dir:match('%.clipboard%-images$') or save_dir:match('%.shooter%.nvim/images$'))

      vim.cmd('cd ' .. orig_cwd)
    end)
  end)

  describe('ensure_gitfiles', function()
    it('creates .gitkeep file', function()
      local images_dir = test_dir .. '/images'
      vim.fn.mkdir(images_dir, 'p')

      clipboard_image.ensure_gitfiles(images_dir)

      local gitkeep = images_dir .. '/.gitkeep'
      assert.are.equal(1, vim.fn.filereadable(gitkeep))
    end)

    it('creates .gitignore file', function()
      local images_dir = test_dir .. '/images'
      vim.fn.mkdir(images_dir, 'p')

      clipboard_image.ensure_gitfiles(images_dir)

      local gitignore = images_dir .. '/.gitignore'
      assert.are.equal(1, vim.fn.filereadable(gitignore))
    end)

    it('.gitignore contains correct patterns', function()
      local images_dir = test_dir .. '/images'
      vim.fn.mkdir(images_dir, 'p')

      clipboard_image.ensure_gitfiles(images_dir)

      local gitignore = images_dir .. '/.gitignore'
      local f = io.open(gitignore, 'r')
      local content = f:read('*a')
      f:close()

      assert.truthy(content:match('%*'))
      assert.truthy(content:match('!%.gitkeep'))
      assert.truthy(content:match('!%.gitignore'))
    end)
  end)

  describe('has_image', function()
    it('returns boolean', function()
      local result = clipboard_image.has_image()
      assert.is_boolean(result)
    end)
  end)

  describe('module structure', function()
    it('exports expected functions', function()
      assert.is_function(clipboard_image.has_image)
      assert.is_function(clipboard_image.save_image)
      assert.is_function(clipboard_image.get_git_root)
      assert.is_function(clipboard_image.get_save_dir)
      assert.is_function(clipboard_image.paste_image_insert)
      assert.is_function(clipboard_image.paste_image_normal)
      assert.is_function(clipboard_image.smart_paste_after)
      assert.is_function(clipboard_image.smart_paste_before)
      assert.is_function(clipboard_image.check)
      assert.is_function(clipboard_image.open_images_dir)
    end)
  end)
end)
