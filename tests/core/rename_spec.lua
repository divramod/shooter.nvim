-- Tests for shooter.core.rename
local rename = require('shooter.core.rename')
local utils = require('shooter.utils')

describe('shooter.core.rename', function()
  local test_dir = '/tmp/shooter_rename_test'

  before_each(function()
    os.execute('mkdir -p ' .. test_dir)
  end)

  after_each(function()
    os.execute('rm -rf ' .. test_dir)
  end)

  describe('update_title_in_file (via perform_rename)', function()
    it('should preserve file content when updating title', function()
      local filepath = test_dir .. '/test-file.md'
      local original_content = [[# Old Title

## shot 1
some content here

## shot 2
more content
]]
      utils.write_file(filepath, original_content)

      -- We can't call update_title_in_file directly (local), but we can verify
      -- that after rename the content is preserved by checking the file
      local success, err, info = rename.perform_rename(filepath, 'new-file.md')

      assert.is_true(success)
      local new_content = utils.read_file(info.new_path)
      -- Content should be preserved (title not updated by perform_rename alone)
      assert.truthy(new_content:find('## shot 1'))
      assert.truthy(new_content:find('some content here'))
      assert.truthy(new_content:find('## shot 2'))
      assert.truthy(new_content:find('more content'))
    end)
  end)

  describe('perform_rename', function()
    it('should rename file successfully', function()
      local old_path = test_dir .. '/old-name.md'
      utils.write_file(old_path, '# Test content')

      local success, err, info = rename.perform_rename(old_path, 'new-name.md')

      assert.is_true(success)
      assert.is_nil(err)
      assert.equals(test_dir .. '/new-name.md', info.new_path)
      assert.equals(1, vim.fn.filereadable(test_dir .. '/new-name.md'))
      assert.equals(0, vim.fn.filereadable(old_path))
    end)

    it('should fail if target already exists', function()
      local old_path = test_dir .. '/old-name.md'
      local existing_path = test_dir .. '/existing.md'
      utils.write_file(old_path, '# Test')
      utils.write_file(existing_path, '# Existing')

      local success, err = rename.perform_rename(old_path, 'existing.md')

      assert.is_false(success)
      assert.truthy(err:find('already exists'))
    end)

    it('should fail if name unchanged', function()
      local old_path = test_dir .. '/same-name.md'
      utils.write_file(old_path, '# Test')

      local success, err = rename.perform_rename(old_path, 'same-name.md')

      assert.is_false(success)
      assert.truthy(err:find('unchanged'))
    end)

    it('should fail with nil parameters', function()
      local success, err = rename.perform_rename(nil, 'name.md')
      assert.is_false(success)
      assert.truthy(err:find('Invalid'))
    end)
  end)
end)
