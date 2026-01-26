-- Test suite for shooter.dashboard.data module
local data = require('shooter.dashboard.data')

describe('dashboard.data module', function()
  local test_dir
  local test_file

  before_each(function()
    -- Create temp directory structure
    test_dir = vim.fn.tempname()
    vim.fn.mkdir(test_dir .. '/plans/prompts', 'p')
  end)

  after_each(function()
    -- Clean up temp files
    if test_dir then
      vim.fn.delete(test_dir, 'rf')
    end
  end)

  describe('get_open_shots', function()
    it('finds open shots in a file', function()
      test_file = test_dir .. '/plans/prompts/test.md'
      local f = io.open(test_file, 'w')
      f:write([[# Test File

## shot 3
Third shot content

## x shot 2 (2026-01-21 10:00:00)
Done shot

## shot 1
First shot content
]])
      f:close()

      local shots = data.get_open_shots(test_file)

      assert.are.equal(2, #shots)
      assert.are.equal(3, shots[1].number)
      assert.are.equal(1, shots[2].number)
    end)

    it('returns empty array for file with no open shots', function()
      test_file = test_dir .. '/plans/prompts/test.md'
      local f = io.open(test_file, 'w')
      f:write([[# Test File

## x shot 1 (2026-01-21 10:00:00)
Done shot
]])
      f:close()

      local shots = data.get_open_shots(test_file)

      assert.are.equal(0, #shots)
    end)

    it('extracts preview from next non-empty line', function()
      test_file = test_dir .. '/plans/prompts/test.md'
      local f = io.open(test_file, 'w')
      f:write([[# Test File

## shot 1
This is the preview line
More content here
]])
      f:close()

      local shots = data.get_open_shots(test_file)

      assert.are.equal(1, #shots)
      assert.are.equal('This is the preview line', shots[1].preview)
    end)
  end)

  describe('get_file_title', function()
    it('extracts title from first heading', function()
      test_file = test_dir .. '/plans/prompts/test.md'
      local f = io.open(test_file, 'w')
      f:write([[# 2026-01-21 - My Feature

## shot 1
Content
]])
      f:close()

      local title = data.get_file_title(test_file)

      assert.are.equal('2026-01-21 - My Feature', title)
    end)

    it('returns nil for file without heading', function()
      test_file = test_dir .. '/plans/prompts/test.md'
      local f = io.open(test_file, 'w')
      f:write('No heading here\nJust text\n')
      f:close()

      local title = data.get_file_title(test_file)

      assert.is_nil(title)
    end)
  end)

  describe('get_repo_name', function()
    it('extracts repo name from path', function()
      local name = data.get_repo_name('/Users/test/projects/my-repo')

      assert.are.equal('my-repo', name)
    end)
  end)

  describe('get_repo_files', function()
    it('finds files with open shots', function()
      -- Create a file with open shots
      test_file = test_dir .. '/plans/prompts/test.md'
      local f = io.open(test_file, 'w')
      f:write([[# Test Feature

## shot 1
Content here
]])
      f:close()

      local result = data.get_repo_files(test_dir)

      assert.are.equal(1, #result.files)
      assert.are.equal('test.md', result.files[1].name)
      assert.are.equal(1, #result.files[1].shots)
    end)

    it('excludes files with no open shots', function()
      -- Create a file with only done shots
      test_file = test_dir .. '/plans/prompts/done.md'
      local f = io.open(test_file, 'w')
      f:write([[# Done Feature

## x shot 1 (2026-01-21 10:00:00)
Completed
]])
      f:close()

      local result = data.get_repo_files(test_dir)

      assert.are.equal(0, #result.files)
    end)
  end)
end)
