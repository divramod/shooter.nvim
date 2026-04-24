-- Tests for shooter.core.masterplan
local masterplan = require('shooter.core.masterplan')
local utils = require('shooter.utils')

describe('shooter.core.masterplan', function()
  local repo = '/tmp/shooter_masterplan_test'
  local path = repo .. '/docs/plans/masterplan.md'

  local function write_plan(content)
    vim.fn.mkdir(repo .. '/docs/plans', 'p')
    utils.write_file(path, content)
  end

  local function read_plan()
    return utils.read_file(path) or ''
  end

  before_each(function()
    os.execute('rm -rf ' .. repo)
    os.execute('mkdir -p ' .. repo)
  end)

  after_each(function()
    os.execute('rm -rf ' .. repo)
  end)

  describe('slugify', function()
    it('lowercases and replaces special signs with hyphens', function()
      assert.equals('dev-worktrees-databases-common-tools',
        masterplan.slugify('dev (worktrees, databases, common tools) \\'))
    end)

    it('collapses runs of special chars and trims', function()
      assert.equals('foo-bar-baz', masterplan.slugify('  Foo  &&  BAR / baz!'))
    end)

    it('preserves already-clean slugs', function()
      assert.equals('merge-hal-skills', masterplan.slugify('merge-hal-skills'))
    end)
  end)

  describe('get_title', function()
    it('includes alias from .hal/ALIAS when present', function()
      vim.fn.mkdir(repo .. '/.hal', 'p')
      utils.write_file(repo .. '/.hal/ALIAS', 'shov\n')
      local title = masterplan.get_title(repo)
      -- repo basename is the tail of the path
      local tail = vim.fn.fnamemodify(repo, ':t')
      assert.equals('# masterplan ' .. tail .. ' (shov)', title)
    end)

    it('omits alias when .hal/ALIAS is missing', function()
      local title = masterplan.get_title(repo)
      local tail = vim.fn.fnamemodify(repo, ':t')
      assert.equals('# masterplan ' .. tail, title)
    end)
  end)

  describe('fix (renumbering in ## next plans)', function()
    it('renumbers sequentially, slugifies pre-paren name, preserves parens', function()
      -- Seed docs/plans with a folder at 0004, so next plans starts at 0005.
      vim.fn.mkdir(repo .. '/docs/plans/0004-seeded', 'p')
      write_plan(table.concat({
        '# old title',
        '',
        '## next plans',
        '- 0006-merge-hal-skills',
        '- 0006-rs-app-fix',
        '- 0008-ts-lib-fix',
        '- ????-conformity',
        '- dev (worktrees, databases, common tools)',
        '',
      }, '\n'))

      assert.is_true(masterplan.fix(repo))
      local out = read_plan()
      assert.truthy(out:find('- 0005-merge-hal-skills', 1, true))
      assert.truthy(out:find('- 0006-rs-app-fix', 1, true))
      assert.truthy(out:find('- 0007-ts-lib-fix', 1, true))
      assert.truthy(out:find('- 0008-conformity', 1, true))
      assert.truthy(out:find(
        '- 0009-dev (worktrees, databases, common tools)', 1, true))
    end)

    it('preserves (description) suffix on already-numbered entries', function()
      -- Seed max = 0024 so single entry renumbers to 0025.
      vim.fn.mkdir(repo .. '/docs/plans/0024-seeded', 'p')
      write_plan(table.concat({
        '## next plans',
        '- 0025-context (agent.md, memory, decisions, instructions)',
        '',
      }, '\n'))
      assert.is_true(masterplan.fix(repo))
      local out = read_plan()
      assert.truthy(out:find(
        '- 0025-context (agent.md, memory, decisions, instructions)',
        1, true))
    end)

    it('preserves indented sub-notes beneath a plan', function()
      write_plan(table.concat({
        '## next plans',
        '- some plan (some description)',
        '  - some notes for the plan',
        '    - some subnotes for the plan',
        '- next one',
        '',
      }, '\n'))
      assert.is_true(masterplan.fix(repo))
      local out = read_plan()
      assert.truthy(out:find('- 0001-some-plan (some description)', 1, true))
      assert.truthy(out:find('  - some notes for the plan', 1, true))
      assert.truthy(out:find('    - some subnotes for the plan', 1, true))
      assert.truthy(out:find('- 0002-next-one', 1, true))
      -- Notes must attach to the first plan, not the second
      local idx_notes = out:find('some notes for the plan', 1, true)
      local idx_next = out:find('0002-next-one', 1, true)
      assert.is_true(idx_notes < idx_next)
    end)

    it('starts from 0001 when first entry has no number', function()
      write_plan('## next plans\n- foo\n- bar\n')
      assert.is_true(masterplan.fix(repo))
      local out = read_plan()
      assert.truthy(out:find('- 0001-foo', 1, true))
      assert.truthy(out:find('- 0002-bar', 1, true))
    end)

    it('preserves the (timestamp) suffix on ## done entries', function()
      write_plan(table.concat({
        '## done',
        '- 0001-refactoring-04 (2026-04-23 06:12:00)',
        '',
      }, '\n'))
      assert.is_true(masterplan.fix(repo))
      local out = read_plan()
      assert.truthy(out:find('- 0001-refactoring-04 (2026-04-23 06:12:00)',
        1, true))
    end)

    it('starting number comes from max(docs/plans folders) + 1', function()
      vim.fn.mkdir(repo .. '/docs/plans/0007-foo', 'p')
      vim.fn.mkdir(repo .. '/docs/plans/0012-bar', 'p')
      write_plan('## next plans\n- alpha\n- beta\n')
      assert.is_true(masterplan.fix(repo))
      local out = read_plan()
      assert.truthy(out:find('- 0013-alpha', 1, true))
      assert.truthy(out:find('- 0014-beta', 1, true))
    end)

    it('starting number also considers in-progress/backlog/done numbers', function()
      -- docs/plans is empty; max comes from done entry 0020
      write_plan(table.concat({
        '## in progress',
        '',
        '## next plans',
        '- alpha',
        '',
        '## backlog',
        '',
        '## done',
        '- 0020-old-stuff (2026-01-01 00:00:00)',
        '',
      }, '\n'))
      assert.is_true(masterplan.fix(repo))
      local out = read_plan()
      assert.truthy(out:find('- 0021-alpha', 1, true))
    end)

    it('does not renumber ## in progress or ## backlog', function()
      write_plan(table.concat({
        '## in progress',
        '- 0004-repo-root-cleanup',
        '',
        '## backlog',
        '- 0003-ios-improvements',
        '',
      }, '\n'))
      assert.is_true(masterplan.fix(repo))
      local out = read_plan()
      assert.truthy(out:find('- 0004-repo-root-cleanup', 1, true))
      assert.truthy(out:find('- 0003-ios-improvements', 1, true))
    end)
  end)

  describe('fix (structure)', function()
    it('sets canonical title from folder name and alias', function()
      vim.fn.mkdir(repo .. '/.hal', 'p')
      utils.write_file(repo .. '/.hal/ALIAS', 'shov\n')
      write_plan('# wrong title\n\n## next plans\n- foo\n')
      assert.is_true(masterplan.fix(repo))
      local out = read_plan()
      local tail = vim.fn.fnamemodify(repo, ':t')
      assert.truthy(out:find('^# masterplan ' .. tail .. ' %(shov%)'))
    end)

    it('ensures the four sections in canonical order', function()
      write_plan('## done\n- x\n\n## next plans\n- y\n')
      assert.is_true(masterplan.fix(repo))
      local out = read_plan()
      local i_prog = out:find('## in progress', 1, true)
      local i_next = out:find('## next plans', 1, true)
      local i_back = out:find('## backlog', 1, true)
      local i_done = out:find('## done', 1, true)
      assert.is_truthy(i_prog)
      assert.is_truthy(i_next)
      assert.is_truthy(i_back)
      assert.is_truthy(i_done)
      assert.is_true(i_prog < i_next)
      assert.is_true(i_next < i_back)
      assert.is_true(i_back < i_done)
    end)

    it('collapses multiple blank lines between plans to single blanks', function()
      write_plan(table.concat({
        '# t',
        '',
        '',
        '## next plans',
        '- 0001-foo',
        '',
        '',
        '',
        '- 0002-bar',
        '',
      }, '\n'))
      assert.is_true(masterplan.fix(repo))
      assert.is_nil(read_plan():find('\n\n\n', 1, true))
    end)

    it('creates the file when missing', function()
      assert.is_true(masterplan.fix(repo))
      assert.is_true(utils.file_exists(path))
    end)
  end)

  describe('fix (plan shotfile sync)', function()
    local plans_dir = repo .. '/.hal/util/shooter/shotfiles/docs/plans'

    it('creates a missing plan shotfile for each referenced plan', function()
      write_plan(table.concat({
        '## in progress',
        '- 0001-alpha',
        '',
        '## next plans',
        '- beta',
        '',
        '## backlog',
        '- 0003-gamma',
        '',
        '## done',
        '- 0002-delta (2026-01-01 00:00:00)',
        '',
      }, '\n'))
      assert.is_true(masterplan.fix(repo))
      assert.is_true(utils.file_exists(plans_dir .. '/0001-alpha.md'))
      -- After renumbering with start = max(0001, 0002, 0003) + 1 = 0004, beta → 0004-beta
      assert.is_true(utils.file_exists(plans_dir .. '/0004-beta.md'))
      assert.is_true(utils.file_exists(plans_dir .. '/0003-gamma.md'))
      assert.is_true(utils.file_exists(plans_dir .. '/0002-delta.md'))
      -- New files carry the canonical title
      local content = utils.read_file(plans_dir .. '/0004-beta.md')
      assert.truthy(content:find('# docs/plans/0004%-beta'))
    end)

    it('renames a drifted plan shotfile when next plans is renumbered', function()
      vim.fn.mkdir(plans_dir, 'p')
      -- Simulate drift: the file on disk is numbered 0009, but after renumbering
      -- the plan will become 0005.
      utils.write_file(plans_dir .. '/0009-merge-hal-skills.md',
        '# docs/plans/0009-merge-hal-skills\n\nbody\n')
      vim.fn.mkdir(repo .. '/docs/plans/0004-seeded', 'p')  -- forces start=5
      write_plan('## next plans\n- 0009-merge-hal-skills\n')

      assert.is_true(masterplan.fix(repo))
      assert.is_false(utils.file_exists(plans_dir .. '/0009-merge-hal-skills.md'))
      assert.is_true(utils.file_exists(plans_dir .. '/0005-merge-hal-skills.md'))
      local content = utils.read_file(plans_dir .. '/0005-merge-hal-skills.md')
      assert.truthy(content:find('# docs/plans/0005%-merge%-hal%-skills'))
      assert.truthy(content:find('body', 1, true))
    end)

    it('leaves an already-correct plan shotfile in place', function()
      vim.fn.mkdir(plans_dir, 'p')
      local p = plans_dir .. '/0001-alpha.md'
      utils.write_file(p, '# docs/plans/0001-alpha\n\nnotes\n')
      write_plan('## in progress\n- 0001-alpha\n')

      assert.is_true(masterplan.fix(repo))
      assert.is_true(utils.file_exists(p))
      assert.truthy(utils.read_file(p):find('notes', 1, true))
    end)
  end)

  describe('fix (buffer handling)', function()
    it('updates an open buffer in place', function()
      write_plan('## next plans\n- foo\n- bar\n')
      vim.cmd('edit ' .. vim.fn.fnameescape(path))
      local bufnr = vim.api.nvim_get_current_buf()

      assert.is_true(masterplan.fix(repo))

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local joined = table.concat(lines, '\n')
      assert.truthy(joined:find('- 0001-foo', 1, true))
      assert.truthy(joined:find('- 0002-bar', 1, true))
      vim.cmd('bdelete! ' .. bufnr)
    end)
  end)

  describe('mark_done', function()
    local function setup_basic()
      write_plan(table.concat({
        '# masterplan test',
        '',
        '## in progress',
        '- 0004-repo-root-cleanup',
        '',
        '## next plans',
        '- 0005-merge',
        '',
        '## backlog',
        '',
        '## done',
        '- 0001-old (2026-01-01 00:00:00)',
        '',
      }, '\n'))
    end

    it('moves the cursor line to the top of ## done with a timestamp', function()
      setup_basic()
      -- Line 4 is `- 0004-repo-root-cleanup`
      assert.is_true(masterplan.mark_done(repo, 4))
      local out = read_plan()
      -- Entry is no longer under ## in progress
      local ip_start = out:find('## in progress', 1, true)
      local np_start = out:find('## next plans', 1, true)
      local ip_section = out:sub(ip_start, np_start - 1)
      assert.is_nil(ip_section:find('0004-repo-root-cleanup', 1, true))
      -- And appears under ## done with a (YYYY-MM-DD HH:MM:SS) suffix
      local done_start = out:find('## done', 1, true)
      local done_section = out:sub(done_start)
      assert.truthy(done_section:find(
        '- 0004%-repo%-root%-cleanup %(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%)'))
    end)

    it('refuses to re-mark an entry already in ## done', function()
      setup_basic()
      -- Line 12 is the existing done entry
      local ok, err = masterplan.mark_done(repo, 12)
      assert.is_false(ok)
      assert.truthy(err:find('already in done'))
    end)

    it('returns an error when cursor is not on a plan line', function()
      setup_basic()
      -- Line 1 is the title — not a plan entry
      local ok, err = masterplan.mark_done(repo, 1)
      assert.is_false(ok)
      assert.truthy(err)
    end)

    it('creates ## done if it does not exist', function()
      write_plan('## in progress\n- 0001-foo\n')
      assert.is_true(masterplan.mark_done(repo, 2))
      local out = read_plan()
      assert.truthy(out:find('## done', 1, true))
      assert.truthy(out:find('- 0001-foo (', 1, true))
    end)

    it('also handles the case where body already carries a (description)', function()
      -- Body with parens should not have the parens mistaken for a timestamp.
      write_plan(table.concat({
        '## in progress',
        '- 0004-foo (some description)',
        '',
        '## done',
        '',
      }, '\n'))
      assert.is_true(masterplan.mark_done(repo, 2))
      local out = read_plan()
      -- Description is preserved; a NEW timestamp paren is appended.
      assert.truthy(out:find('%- 0004%-foo %(some description%) %(%d%d%d%d%-'))
    end)

    it('moves indented child notes together with the plan', function()
      write_plan(table.concat({
        '## in progress',
        '- 0004-cleanup (some notes about it)',
        '  - first note',
        '    - nested note',
        '',
        '## next plans',
        '- 0005-other',
        '',
        '## backlog',
        '',
        '## done',
        '',
      }, '\n'))
      -- Line 2 is `- 0004-cleanup (some notes about it)`
      assert.is_true(masterplan.mark_done(repo, 2))
      local out = read_plan()

      -- No trace under ## in progress
      local ip_start = out:find('## in progress', 1, true)
      local np_start = out:find('## next plans', 1, true)
      local ip_section = out:sub(ip_start, np_start - 1)
      assert.is_nil(ip_section:find('cleanup', 1, true))
      assert.is_nil(ip_section:find('first note', 1, true))

      -- Entry + children live under ## done, timestamp appended to entry
      local done_start = out:find('## done', 1, true)
      local done_section = out:sub(done_start)
      assert.truthy(done_section:find(
        '%- 0004%-cleanup %(some notes about it%) %(%d%d%d%d%-%d%d%-%d%d'))
      assert.truthy(done_section:find('  - first note', 1, true))
      assert.truthy(done_section:find('    - nested note', 1, true))
    end)
  end)

  describe('extract_plan_name', function()
    it('extracts NNNN-slug from a bullet line', function()
      assert.equals('0005-merge-hal-skills',
        masterplan.extract_plan_name('- 0005-merge-hal-skills'))
    end)

    it('ignores trailing (description) and extra text', function()
      assert.equals('0005-merge-hal-skills',
        masterplan.extract_plan_name('- 0005-merge-hal-skills (some notes)'))
    end)

    it('returns nil when the line has no plan reference', function()
      assert.is_nil(masterplan.extract_plan_name('- some plain note'))
      assert.is_nil(masterplan.extract_plan_name(''))
      assert.is_nil(masterplan.extract_plan_name(nil))
    end)

    it('works on indented child note lines (no plan)', function()
      assert.is_nil(masterplan.extract_plan_name('  - a child note'))
    end)
  end)

  describe('resolve_plan_file', function()
    local plans_dir = repo .. '/.hal/util/shooter/shotfiles/docs/plans'

    it('returns exists when the target file is already there', function()
      vim.fn.mkdir(plans_dir, 'p')
      utils.write_file(plans_dir .. '/0005-merge-hal-skills.md', '# x\n')
      local action, path = masterplan.resolve_plan_file(repo, '0005-merge-hal-skills')
      assert.equals('exists', action)
      assert.equals(plans_dir .. '/0005-merge-hal-skills.md', path)
    end)

    it('returns rename when only a different-numbered match exists', function()
      vim.fn.mkdir(plans_dir, 'p')
      utils.write_file(plans_dir .. '/0003-merge-hal-skills.md', '# x\n')
      local action, target, old = masterplan.resolve_plan_file(repo, '0005-merge-hal-skills')
      assert.equals('rename', action)
      assert.equals(plans_dir .. '/0005-merge-hal-skills.md', target)
      assert.equals(plans_dir .. '/0003-merge-hal-skills.md', old)
    end)

    it('returns new when no match exists', function()
      local action, path = masterplan.resolve_plan_file(repo, '0007-never-seen')
      assert.equals('new', action)
      assert.equals(plans_dir .. '/0007-never-seen.md', path)
    end)

    it('returns new when plans dir is missing', function()
      assert.is_false(utils.dir_exists(plans_dir))
      local action = masterplan.resolve_plan_file(repo, '0001-foo')
      assert.equals('new', action)
    end)
  end)

  describe('edit_plan_at_line', function()
    local plans_dir = repo .. '/.hal/util/shooter/shotfiles/docs/plans'

    after_each(function()
      -- Close any buffers opened during test so they don't leak
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
          local name = vim.api.nvim_buf_get_name(buf)
          if name:find(repo, 1, true) then
            vim.cmd('silent! bwipeout! ' .. buf)
          end
        end
      end
    end)

    it('opens an existing plan shotfile', function()
      vim.fn.mkdir(plans_dir, 'p')
      local p = plans_dir .. '/0005-merge-hal-skills.md'
      utils.write_file(p, '# docs/plans/0005-merge-hal-skills\n\nbody\n')

      local ok, msg = masterplan.edit_plan_at_line(repo, '- 0005-merge-hal-skills')
      assert.is_true(ok, msg)
      assert.equals('opened', msg)
      -- Current buffer points at the plan file
      local bufname = vim.api.nvim_buf_get_name(0)
      assert.truthy(bufname:find(p, 1, true) or
        (vim.uv.fs_realpath(bufname) or '') == (vim.uv.fs_realpath(p) or p))
    end)

    it('renames an existing file with a different number and adapts title', function()
      vim.fn.mkdir(plans_dir, 'p')
      local old = plans_dir .. '/0003-merge-hal-skills.md'
      local target = plans_dir .. '/0005-merge-hal-skills.md'
      utils.write_file(old, '# docs/plans/0003-merge-hal-skills\n\nold body\n')

      local ok, msg = masterplan.edit_plan_at_line(repo, '- 0005-merge-hal-skills')
      assert.is_true(ok, msg)
      assert.equals('renamed', msg)
      -- Old path gone, new path present
      assert.is_false(utils.file_exists(old))
      assert.is_true(utils.file_exists(target))
      -- Title was updated to the new path
      local content = utils.read_file(target) or ''
      assert.truthy(content:find('# docs/plans/0005%-merge%-hal%-skills'))
      assert.truthy(content:find('old body', 1, true))
    end)

    it('creates a new file with a correct title when none exists', function()
      local target = plans_dir .. '/0007-fresh-plan.md'
      assert.is_false(utils.file_exists(target))

      local ok, msg = masterplan.edit_plan_at_line(repo, '- 0007-fresh-plan (later, do it)')
      assert.is_true(ok, msg)
      assert.equals('created', msg)
      local content = utils.read_file(target) or ''
      assert.truthy(content:find('# docs/plans/0007%-fresh%-plan'))
    end)

    it('errors when the line has no plan reference', function()
      local ok, err = masterplan.edit_plan_at_line(repo, '  - just a note')
      assert.is_false(ok)
      assert.truthy(err)
    end)
  end)

  describe('open_plan_file', function()
    local plan_dir = repo .. '/docs/plans/0005-merge-hal-skills'

    after_each(function()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
          local name = vim.api.nvim_buf_get_name(buf)
          if name:find(repo, 1, true) then
            vim.cmd('silent! bwipeout! ' .. buf)
          end
        end
      end
    end)

    it('opens docs/plans/<plan>/plan.md for a valid plan line', function()
      vim.fn.mkdir(plan_dir, 'p')
      utils.write_file(plan_dir .. '/plan.md', '# plan\n')
      local ok, msg = masterplan.open_plan_file(repo,
        '- 0005-merge-hal-skills', 'plan')
      assert.is_true(ok, msg)
      assert.equals('opened', msg)
      local bufname = vim.api.nvim_buf_get_name(0)
      assert.truthy(bufname:find('plan.md', 1, true))
    end)

    it('opens docs/plans/<plan>/context.md', function()
      vim.fn.mkdir(plan_dir, 'p')
      utils.write_file(plan_dir .. '/context.md', '# context\n')
      local ok = masterplan.open_plan_file(repo,
        '- 0005-merge-hal-skills', 'context')
      assert.is_true(ok)
      assert.truthy(vim.api.nvim_buf_get_name(0):find('context.md', 1, true))
    end)

    it('opens docs/plans/<plan>/spec.md', function()
      vim.fn.mkdir(plan_dir, 'p')
      utils.write_file(plan_dir .. '/spec.md', '# spec\n')
      local ok = masterplan.open_plan_file(repo,
        '- 0005-merge-hal-skills', 'spec')
      assert.is_true(ok)
      assert.truthy(vim.api.nvim_buf_get_name(0):find('spec.md', 1, true))
    end)

    it('reports no plan on line when cursor line has no plan reference', function()
      local ok, err = masterplan.open_plan_file(repo, '  - a child note', 'plan')
      assert.is_false(ok)
      assert.truthy(err:find('no plan on current line', 1, true))
    end)

    it('reports missing file when the specific kind does not exist', function()
      vim.fn.mkdir(plan_dir, 'p')
      utils.write_file(plan_dir .. '/plan.md', '# plan\n')
      local ok, err = masterplan.open_plan_file(repo,
        '- 0005-merge-hal-skills', 'spec')
      assert.is_false(ok)
      assert.truthy(err:find('no spec.md for 0005-merge-hal-skills', 1, true))
    end)

    it('reports missing file when the plan folder does not exist', function()
      local ok, err = masterplan.open_plan_file(repo,
        '- 0099-missing-plan', 'plan')
      assert.is_false(ok)
      assert.truthy(err:find('no plan.md for 0099-missing-plan', 1, true))
    end)

    it('rejects an invalid kind', function()
      local ok, err = masterplan.open_plan_file(repo,
        '- 0005-merge-hal-skills', 'readme')
      assert.is_false(ok)
      assert.truthy(err:find('invalid kind', 1, true))
    end)
  end)
end)
