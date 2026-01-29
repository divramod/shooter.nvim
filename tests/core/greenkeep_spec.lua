-- Tests for shooter.core.greenkeep
local greenkeep = require('shooter.core.greenkeep')

describe('shooter.core.greenkeep', function()
  describe('convert_date', function()
    it('should convert old format to new format', function()
      local result = greenkeep.convert_date('2026', '01', '19', '07', '41')
      assert.equals('(2026-01-19 07:41:00)', result)
    end)

    it('should preserve leading zeros', function()
      local result = greenkeep.convert_date('2026', '01', '01', '00', '00')
      assert.equals('(2026-01-01 00:00:00)', result)
    end)
  end)

  describe('slugify', function()
    it('should lowercase and replace spaces with dashes', function()
      assert.equals('hello-world', greenkeep.slugify('Hello World'))
    end)

    it('should remove special characters', function()
      assert.equals('test-title', greenkeep.slugify('Test: Title!'))
    end)

    it('should handle multiple spaces', function()
      assert.equals('foo-bar', greenkeep.slugify('foo   bar'))
    end)
  end)

  describe('extract_slug_from_filename', function()
    it('should extract slug from YYYYMMDD_HHMM_slug.md pattern', function()
      assert.equals('my-feature', greenkeep.extract_slug_from_filename('20260118_2338_my-feature.md'))
    end)

    it('should extract slug from YYYY-MM-DD_slug.md pattern', function()
      assert.equals('my-feature', greenkeep.extract_slug_from_filename('2026-01-18_my-feature.md'))
    end)

    it('should return nil for new format filenames', function()
      assert.is_nil(greenkeep.extract_slug_from_filename('my-feature.md'))
    end)
  end)

  describe('process_header', function()
    it('should convert old header format to new', function()
      local new_line, updated = greenkeep.process_header('# 2026-01-18 - Layout')
      assert.equals('# layout', new_line)
      assert.is_true(updated)
    end)

    it('should slugify multi-word titles', function()
      local new_line, updated = greenkeep.process_header('# 2026-01-18 - My Feature Name')
      assert.equals('# my-feature-name', new_line)
      assert.is_true(updated)
    end)

    it('should not modify new format headers', function()
      local new_line, updated = greenkeep.process_header('# my-feature')
      assert.equals('# my-feature', new_line)
      assert.is_false(updated)
    end)

    it('should not modify non-header lines', function()
      local new_line, updated = greenkeep.process_header('Some content here')
      assert.equals('Some content here', new_line)
      assert.is_false(updated)
    end)
  end)

  describe('process_shot_date', function()
    it('should convert old date format in executed shot header', function()
      local new_line, updated = greenkeep.process_shot_date('## x shot 1 (20260119_0741)')
      assert.equals('## x shot 1 (2026-01-19 07:41:00)', new_line)
      assert.is_true(updated)
    end)

    it('should not modify lines already in new format', function()
      local line = '## x shot 276 (2026-01-23 09:25:41)'
      local new_line, updated = greenkeep.process_shot_date(line)
      assert.equals(line, new_line)
      assert.is_false(updated)
    end)

    it('should not modify open shot headers', function()
      local line = '## shot 5'
      local new_line, updated = greenkeep.process_shot_date(line)
      assert.equals(line, new_line)
      assert.is_false(updated)
    end)
  end)

  describe('process_file_content', function()
    local test_file = '/tmp/test_greenkeep_content.md'
    local utils = require('shooter.utils')

    after_each(function()
      os.remove(test_file)
    end)

    it('should process both header and shot dates', function()
      local content = [[# 2026-01-18 - My Feature
## x shot 1 (20260119_0741)
Some content here
## x shot 2 (20260120_0830)
More content
]]
      utils.write_file(test_file, content)

      local shots, header_updated, err = greenkeep.process_file_content(test_file)
      assert.is_nil(err)
      assert.equals(2, shots)
      assert.is_true(header_updated)

      local new_content = utils.read_file(test_file)
      assert.truthy(new_content:find('# my%-feature', 1, false))
      assert.truthy(new_content:find('2026%-01%-19 07:41:00', 1, false))
    end)

    it('should not modify file with only new format', function()
      local content = [[# my-feature
## x shot 1 (2026-01-19 07:41:00)
]]
      utils.write_file(test_file, content)

      local shots, header_updated, err = greenkeep.process_file_content(test_file)
      assert.is_nil(err)
      assert.equals(0, shots)
      assert.is_false(header_updated)
    end)
  end)

  describe('rename_file_if_needed', function()
    local test_dir = '/tmp/greenkeep_test_files'
    local utils = require('shooter.utils')

    before_each(function()
      os.execute('mkdir -p ' .. test_dir)
    end)

    after_each(function()
      os.execute('rm -rf ' .. test_dir)
    end)

    it('should rename YYYYMMDD_HHMM_slug.md files', function()
      local old_path = test_dir .. '/20260118_2338_my-feature.md'
      utils.write_file(old_path, 'test content')

      local new_path, renamed = greenkeep.rename_file_if_needed(old_path)
      assert.is_true(renamed)
      assert.equals(test_dir .. '/my-feature.md', new_path)
      assert.equals(1, vim.fn.filereadable(new_path))
    end)

    it('should not rename files with new naming', function()
      local path = test_dir .. '/my-feature.md'
      utils.write_file(path, 'test content')

      local new_path, renamed = greenkeep.rename_file_if_needed(path)
      assert.is_false(renamed)
      assert.equals(path, new_path)
    end)
  end)
end)
