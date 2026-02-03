-- Test suite for shooter.telescope.helpers module
-- Skip if telescope not available (headless testing)
local ok, helpers = pcall(require, 'shooter.telescope.helpers')
if not ok then
  describe('telescope helpers (skipped - telescope not available)', function()
    it('skipped', function() end)
  end)
  return
end

describe('telescope helpers', function()
  describe('module structure', function()
    it('exports expected functions', function()
      assert.is_function(helpers.find_open_shots)
      assert.is_function(helpers.make_shot_entry)
      assert.is_function(helpers.get_repo_prompt_files)
      assert.is_function(helpers.get_all_repo_shots)
      assert.is_function(helpers.read_lines)
      assert.is_function(helpers.get_target_file)
    end)
  end)

  describe('find_open_shots', function()
    it('finds open shots in lines', function()
      local lines = {
        '# Title',
        '',
        '## shot 1',
        'Shot 1 content',
        '',
        '## x shot 2',
        'Shot 2 executed',
        '',
        '## shot 3',
        'Shot 3 content',
      }
      local shots = helpers.find_open_shots(lines)
      assert.are.equal(2, #shots)
      assert.are.equal(3, shots[1].header_line)
      assert.are.equal(9, shots[2].header_line)
    end)

    it('returns empty table when no open shots', function()
      local lines = {
        '# Title',
        '',
        '## x shot 1',
        'Executed',
      }
      local shots = helpers.find_open_shots(lines)
      assert.are.equal(0, #shots)
    end)
  end)

  describe('make_shot_entry', function()
    it('creates entry without file prefix by default', function()
      local lines = { '## shot 5', 'Content here' }
      local shot = { header_line = 1, start_line = 1, end_line = 2 }
      local entry = helpers.make_shot_entry(shot, lines, '/path/to/file.md', false, false)
      assert.is_truthy(entry.display:match('^Shot 5:'))
      assert.is_falsy(entry.display:match('%[file%]'))
    end)

    it('creates entry with file prefix when show_file is true', function()
      local lines = { '## shot 5', 'Content here' }
      local shot = { header_line = 1, start_line = 1, end_line = 2 }
      local entry = helpers.make_shot_entry(shot, lines, '/path/to/myfile.md', false, true)
      assert.is_truthy(entry.display:match('%[myfile%]'))
      assert.is_truthy(entry.display:match('Shot 5:'))
    end)
  end)
end)
