-- Tests for shooter.plans.masterplan
local masterplan = require('shooter.plans.masterplan')
local utils = require('shooter.utils')

describe('shooter.plans.masterplan', function()
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

    it('starting number also considers in-progress/planned/backlog/done numbers', function()
      -- docs/plans is empty; max comes from planned entry 0022
      write_plan(table.concat({
        '## in progress',
        '',
        '## planned',
        '- 0022-planned-thing',
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
      assert.truthy(out:find('- 0023-alpha', 1, true))
    end)

    it('does not renumber ## in progress, ## planned, or ## backlog', function()
      write_plan(table.concat({
        '## in progress',
        '- 0004-repo-root-cleanup',
        '',
        '## planned',
        '- 0006-planned-feature',
        '',
        '## backlog',
        '- 0003-ios-improvements',
        '',
      }, '\n'))
      assert.is_true(masterplan.fix(repo))
      local out = read_plan()
      assert.truthy(out:find('- 0004-repo-root-cleanup', 1, true))
      assert.truthy(out:find('- 0006-planned-feature', 1, true))
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

    it('ensures the five sections in canonical order', function()
      write_plan('## done\n- x\n\n## next plans\n- y\n')
      assert.is_true(masterplan.fix(repo))
      local out = read_plan()
      local i_prog = out:find('## in progress', 1, true)
      local i_planned = out:find('## planned', 1, true)
      local i_next = out:find('## next plans', 1, true)
      local i_back = out:find('## backlog', 1, true)
      local i_done = out:find('## done', 1, true)
      assert.is_truthy(i_prog)
      assert.is_truthy(i_planned)
      assert.is_truthy(i_next)
      assert.is_truthy(i_back)
      assert.is_truthy(i_done)
      assert.is_true(i_prog < i_planned)
      assert.is_true(i_planned < i_next)
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

    it('preserves `## planned` entries verbatim and in canonical position', function()
      write_plan(table.concat({
        '## in progress',
        '- 0001-active',
        '',
        '## planned',
        '- 0007-future-feature (with notes)',
        '  - sub-note that travels with planned entry',
        '',
        '## next plans',
        '- alpha',
        '',
      }, '\n'))
      assert.is_true(masterplan.fix(repo))
      local out = read_plan()
      -- Planned entry kept verbatim, including paren and child note
      assert.truthy(out:find('- 0007-future-feature (with notes)', 1, true))
      assert.truthy(out:find('  - sub-note that travels with planned entry', 1, true))
      -- Canonical order: in progress < planned < next plans < backlog < done
      local i_prog = out:find('## in progress', 1, true)
      local i_planned = out:find('## planned', 1, true)
      local i_next = out:find('## next plans', 1, true)
      local i_back = out:find('## backlog', 1, true)
      local i_done = out:find('## done', 1, true)
      assert.is_true(i_prog < i_planned)
      assert.is_true(i_planned < i_next)
      assert.is_true(i_next < i_back)
      assert.is_true(i_back < i_done)
      -- next plans renumbered starting at max(0001, 0007) + 1 = 0008
      assert.truthy(out:find('- 0008-alpha', 1, true))
    end)
  end)

  describe('fix (adopt orphan docs/plans folders)', function()
    it('adds docs/plans folders not referenced anywhere into ## in progress', function()
      -- Masterplan has nothing; docs/plans has three folders.
      vim.fn.mkdir(repo .. '/docs/plans/0001-alpha', 'p')
      vim.fn.mkdir(repo .. '/docs/plans/0002-beta', 'p')
      vim.fn.mkdir(repo .. '/docs/plans/0003-gamma', 'p')
      write_plan('## in progress\n\n## next plans\n\n## backlog\n\n## done\n')
      assert.is_true(masterplan.fix(repo))
      local mp = read_plan()
      local ip = mp:match('## in progress\n(.-)\n## planned')
      assert.truthy(ip)
      assert.truthy(ip:find('- 0001-alpha', 1, true))
      assert.truthy(ip:find('- 0002-beta', 1, true))
      assert.truthy(ip:find('- 0003-gamma', 1, true))
    end)

    it('does not adopt folders already in any masterplan section', function()
      vim.fn.mkdir(repo .. '/docs/plans/0001-already-in-progress', 'p')
      vim.fn.mkdir(repo .. '/docs/plans/0002-already-done', 'p')
      vim.fn.mkdir(repo .. '/docs/plans/0003-already-backlog', 'p')
      vim.fn.mkdir(repo .. '/docs/plans/0004-already-next', 'p')
      -- A new orphan that should get adopted.
      vim.fn.mkdir(repo .. '/docs/plans/0005-brand-new', 'p')
      write_plan(table.concat({
        '## in progress', '- 0001-already-in-progress',
        '## next plans',  '- 0004-already-next',
        '## backlog',     '- 0003-already-backlog',
        '## done',        '- 0002-already-done (2026-01-01 00:00:00)',
      }, '\n'))
      assert.is_true(masterplan.fix(repo))
      local mp = read_plan()
      local ip = mp:match('## in progress\n(.-)\n## planned')
      assert.truthy(ip:find('- 0001-already-in-progress', 1, true))
      assert.truthy(ip:find('- 0005-brand-new', 1, true))
      -- Originals stayed in their sections (in progress didn't absorb them).
      assert.is_nil(ip:find('0003-already-backlog', 1, true))
      assert.is_nil(ip:find('0002-already-done', 1, true))
      assert.is_nil(ip:find('0004-already-next', 1, true))
    end)

    it('sorts ## in progress alphabetically by full NNNN-slug text', function()
      -- Pre-existing in-progress entries in NON-alphabetical order.
      vim.fn.mkdir(repo .. '/docs/plans/0004-apple', 'p')
      vim.fn.mkdir(repo .. '/docs/plans/0001-zebra', 'p')
      -- Orphan that must land in the middle by full-text sort.
      vim.fn.mkdir(repo .. '/docs/plans/0003-mango', 'p')
      write_plan(table.concat({
        '## in progress',
        '- 0004-apple',
        '- 0001-zebra',
      }, '\n'))
      assert.is_true(masterplan.fix(repo))
      local mp = read_plan()
      local ip = mp:match('## in progress\n(.-)\n## planned')
      -- Full-text (number-first) sort: 0001-zebra → 0003-mango → 0004-apple.
      local i_zebra = ip:find('0001-zebra', 1, true)
      local i_mango = ip:find('0003-mango', 1, true)
      local i_apple = ip:find('0004-apple', 1, true)
      assert.is_truthy(i_zebra)
      assert.is_truthy(i_mango)
      assert.is_truthy(i_apple)
      assert.is_true(i_zebra < i_mango)
      assert.is_true(i_mango < i_apple)
    end)

    it('is idempotent — second pf does not duplicate the adopted entry', function()
      vim.fn.mkdir(repo .. '/docs/plans/0007-lonely', 'p')
      write_plan('## in progress\n\n## next plans\n\n## backlog\n\n## done\n')
      assert.is_true(masterplan.fix(repo))
      assert.is_true(masterplan.fix(repo))
      local mp = read_plan()
      local _, count = mp:gsub('0007%-lonely', '')
      assert.equals(1, count)
    end)
  end)

  describe('fix (plan shotfile sync)', function()
    local plans_dir = repo .. '/docs/shotfiles/docs/plans'

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

    it('sweeps stub and same-slug orphans left by earlier renumberings', function()
      vim.fn.mkdir(plans_dir, 'p')
      -- Active plan that the masterplan references.
      utils.write_file(plans_dir .. '/0008-fix-envfile.md',
        '# docs/plans/0008-fix-envfile\n\nnotes\n')
      -- Rule 2: same-slug orphan with non-stub content → also deleted
      -- because the active 0008-fix-envfile.md is the canonical file.
      utils.write_file(plans_dir .. '/0007-fix-envfile.md',
        '# docs/plans/0007-fix-envfile\n\nsome old notes\n')
      -- Rule 1: title-only stub with an unrelated slug → deleted.
      utils.write_file(plans_dir .. '/0002-refactore-general-folder-structure.md',
        '# docs/plans/0002-refactore-general-folder-structure\n')
      -- Preserved: non-stub content, slug does NOT match any active plan.
      utils.write_file(plans_dir .. '/9999-legacy-notes.md',
        '# docs/plans/9999-legacy-notes\n\nimportant user notes here\n')
      -- Preserved: non-NNNN name, non-stub content.
      utils.write_file(plans_dir .. '/conformity.md',
        '# docs/plans/conformity\n\ninteresting spec\n')

      -- Seed docs/plans so max_plan_number=7, next plans starts at 0008
      -- (keeps the fix-envfile plan at 0008 instead of renumbering to 0001).
      vim.fn.mkdir(repo .. '/docs/plans/0007-seeded', 'p')
      write_plan('## next plans\n- 0008-fix-envfile\n')
      assert.is_true(masterplan.fix(repo))

      assert.is_true(utils.file_exists(plans_dir .. '/0008-fix-envfile.md'))
      assert.is_false(utils.file_exists(plans_dir .. '/0007-fix-envfile.md'))
      assert.is_false(utils.file_exists(
        plans_dir .. '/0002-refactore-general-folder-structure.md'))
      assert.is_true(utils.file_exists(plans_dir .. '/9999-legacy-notes.md'))
      assert.is_true(utils.file_exists(plans_dir .. '/conformity.md'))
      assert.truthy(utils.read_file(plans_dir .. '/0008-fix-envfile.md')
        :find('notes', 1, true))
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
      local ip_end = out:find('\n## ', ip_start + 1, true) or #out
      local ip_section = out:sub(ip_start, ip_end)
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
      local ip_end = out:find('\n## ', ip_start + 1, true) or #out
      local ip_section = out:sub(ip_start, ip_end)
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
    local plans_dir = repo .. '/docs/shotfiles/docs/plans'

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
    local plans_dir = repo .. '/docs/shotfiles/docs/plans'

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

  describe('new_plan', function()
    it('creates docs/plans/<NNNN-slug>/plan.md with the next free number', function()
      vim.fn.mkdir(repo .. '/docs/plans/0004-seeded', 'p')
      local ok, path = masterplan.new_plan(repo, 'My Fresh Plan')
      assert.is_true(ok, path)
      assert.equals(repo .. '/docs/plans/0005-my-fresh-plan/plan.md', path)
      assert.is_true(utils.file_exists(path))
      local content = utils.read_file(path) or ''
      assert.truthy(content:find('^# 0005%-my%-fresh%-plan'))
    end)

    it('starts at 0001 when docs/plans is empty', function()
      local ok, path = masterplan.new_plan(repo, 'first one')
      assert.is_true(ok)
      assert.equals(repo .. '/docs/plans/0001-first-one/plan.md', path)
    end)

    it('also considers masterplan sections when picking the next number', function()
      -- docs/plans is empty; masterplan has a ## done entry at 0020.
      write_plan('## done\n- 0020-stuff (2026-01-01 00:00:00)\n')
      local ok, path = masterplan.new_plan(repo, 'alpha')
      assert.is_true(ok)
      assert.equals(repo .. '/docs/plans/0021-alpha/plan.md', path)
    end)

    it('refuses an empty or whitespace title', function()
      local ok1, err1 = masterplan.new_plan(repo, '')
      assert.is_false(ok1); assert.truthy(err1)
      local ok2, err2 = masterplan.new_plan(repo, '   ')
      assert.is_false(ok2); assert.truthy(err2)
    end)

    it('appends the plan to ## next plans in masterplan.md', function()
      write_plan('## in progress\n- 0002-current\n')
      local ok = masterplan.new_plan(repo, 'fresh')
      assert.is_true(ok)
      local mp = read_plan()
      -- Number picked is max(0002) + 1 = 0003; entry lands in next plans.
      assert.truthy(mp:find('## next plans', 1, true))
      local np = mp:match('## next plans.-\n(.-)\n##')
      assert.truthy(np and np:find('- 0003-fresh', 1, true))
    end)

    it('runs fix(): renumbering is idempotent and plan shotfile is created', function()
      vim.fn.mkdir(repo .. '/docs/plans/0004-seeded', 'p')
      write_plan('## done\n- 0003-old (2026-01-01 00:00:00)\n')
      local ok, path = masterplan.new_plan(repo, 'alpha')
      assert.is_true(ok)
      assert.equals(repo .. '/docs/plans/0005-alpha/plan.md', path)

      -- After fix, the next-plans entry keeps its 0005 number
      -- (max_plan_number ignores the 0005-alpha folder because that plan is
      -- in ## next plans).
      local mp = read_plan()
      assert.truthy(mp:find('- 0005-alpha', 1, true))
      assert.is_nil(mp:find('- 0006-alpha', 1, true))

      -- Plan shotfile was synced.
      assert.is_true(utils.file_exists(
        repo .. '/docs/shotfiles/docs/plans/0005-alpha.md'))
    end)

    it('does not duplicate the entry when run twice with the same title', function()
      assert.is_true(masterplan.new_plan(repo, 'twice'))
      assert.is_true(masterplan.new_plan(repo, 'twice'))
      local mp = read_plan()
      assert.truthy(mp:find('- 0001-twice', 1, true))
      assert.truthy(mp:find('- 0002-twice', 1, true))
      -- No phantom second copy of either slot.
      local _, count1 = mp:gsub('0001%-twice', '')
      local _, count2 = mp:gsub('0002%-twice', '')
      assert.equals(1, count1)
      assert.equals(1, count2)
    end)
  end)

  describe('max_plan_number (next-plans aware)', function()
    it('ignores docs/plans folders that match `## next plans` entries', function()
      vim.fn.mkdir(repo .. '/docs/plans/0004-seeded', 'p')
      vim.fn.mkdir(repo .. '/docs/plans/0007-future', 'p')
      local parsed = masterplan.parse(table.concat({
        '## in progress', '- 0004-seeded',
        '## next plans', '- 0007-future',
        '## backlog', '',
        '## done', '',
      }, '\n'))
      assert.equals(4, masterplan.max_plan_number(repo, parsed.sections))
    end)

    it('counts `## planned` entries toward the max', function()
      local parsed = masterplan.parse(table.concat({
        '## in progress', '- 0002-active',
        '## planned', '- 0011-coming-next',
        '## next plans', '',
        '## backlog', '',
        '## done', '',
      }, '\n'))
      assert.equals(11, masterplan.max_plan_number(repo, parsed.sections))
    end)
  end)

  describe('next_free_plan_number', function()
    it('returns max across everything (including next plans) + 1', function()
      vim.fn.mkdir(repo .. '/docs/plans/0002-foo', 'p')
      local parsed = masterplan.parse(table.concat({
        '## next plans', '- 0005-bar',
        '## done', '- 0003-baz (2026-01-01 00:00:00)',
      }, '\n'))
      assert.equals(6, masterplan.next_free_plan_number(repo, parsed.sections))
    end)
  end)

  describe('commit_plans', function()
    local gitrepo = '/tmp/shooter_masterplan_commit_test'
    local mp_path = gitrepo .. '/docs/plans/masterplan.md'
    local shotfiles_plans = gitrepo .. '/docs/shotfiles/docs/plans'

    local function git(...)
      local cmd = { 'git', '-C', gitrepo }
      for _, a in ipairs({ ... }) do table.insert(cmd, a) end
      return vim.fn.system(cmd)
    end
    local function count_commits()
      return tonumber(git('rev-list', '--count', 'HEAD'):match('%d+')) or 0
    end

    before_each(function()
      os.execute('rm -rf ' .. gitrepo)
      os.execute('mkdir -p ' .. gitrepo .. '/docs/plans')
      os.execute('mkdir -p ' .. shotfiles_plans)
      vim.fn.system({ 'git', '-C', gitrepo, 'init', '-q' })
      vim.fn.system({ 'git', '-C', gitrepo, 'config', 'user.email', 't@t' })
      vim.fn.system({ 'git', '-C', gitrepo, 'config', 'user.name', 't' })
      vim.fn.system({ 'git', '-C', gitrepo, 'config', 'commit.gpgsign', 'false' })
      vim.fn.system({ 'git', '-C', gitrepo, 'commit', '--allow-empty', '-q', '-m', 'init' })
    end)

    after_each(function()
      os.execute('rm -rf ' .. gitrepo)
    end)

    it('commits changes under docs/plans and shotfiles/docs/plans', function()
      utils.write_file(mp_path, '# masterplan\n')
      utils.write_file(shotfiles_plans .. '/0001-foo.md', '# docs/plans/0001-foo\n')

      local before = count_commits()
      local ok, msg, committed = masterplan.commit_plans(gitrepo)
      assert.is_true(ok, msg)
      assert.is_true(committed)
      assert.equals(before + 1, count_commits())

      local files_in_commit = git('show', '--name-only', '--format=', 'HEAD')
      assert.truthy(files_in_commit:find('docs/plans/masterplan%.md'))
      assert.truthy(files_in_commit:find(
        'docs/shotfiles/docs/plans/0001%-foo%.md'))

      local subject = git('log', '-1', '--format=%s')
      assert.truthy(subject:find('chore%(plans%): sync'))
    end)

    it('reports no changes when plan folders are clean', function()
      utils.write_file(mp_path, '# masterplan\n')
      git('add', '-A', '--', 'docs/plans')
      git('commit', '-q', '-m', 'seed')

      local before = count_commits()
      local ok, msg, committed = masterplan.commit_plans(gitrepo)
      assert.is_true(ok)
      assert.is_false(committed)
      assert.truthy(msg:find('nothing to commit', 1, true))
      assert.equals(before, count_commits())
    end)

    it('leaves unrelated staged changes out of the commit', function()
      utils.write_file(mp_path, '# masterplan\n')
      utils.write_file(gitrepo .. '/other.txt', 'hello\n')
      git('add', 'other.txt')

      local ok, _, committed = masterplan.commit_plans(gitrepo)
      assert.is_true(ok); assert.is_true(committed)

      local files_in_commit = git('show', '--name-only', '--format=', 'HEAD')
      assert.truthy(files_in_commit:find('docs/plans/masterplan%.md'))
      assert.is_nil(files_in_commit:find('other%.txt'))
      -- And other.txt is still staged
      local staged = git('diff', '--cached', '--name-only')
      assert.truthy(staged:find('other.txt'))
    end)

    it('commits when only one of the two folders has changes', function()
      -- Only shotfiles side has content.
      utils.write_file(shotfiles_plans .. '/0001-alpha.md',
        '# docs/plans/0001-alpha\n')
      local ok, _, committed = masterplan.commit_plans(gitrepo)
      assert.is_true(ok); assert.is_true(committed)
      local files_in_commit = git('show', '--name-only', '--format=', 'HEAD')
      assert.truthy(files_in_commit:find('shotfiles/docs/plans/0001%-alpha%.md'))
    end)

    it('no-op and no-error when neither folder exists', function()
      os.execute('rm -rf ' .. gitrepo .. '/docs/plans')
      os.execute('rm -rf ' .. shotfiles_plans)
      local ok, msg, committed = masterplan.commit_plans(gitrepo)
      assert.is_true(ok)
      assert.is_false(committed)
      assert.truthy(msg:find('no folders', 1, true))
    end)

    it('does not push (no remote ever contacted)', function()
      -- If commit_plans tried to push, `git log origin/main` would reflect it.
      -- Easier assertion: no `origin` remote was added and no push ran.
      utils.write_file(mp_path, '# masterplan\n')
      masterplan.commit_plans(gitrepo)
      local remotes = git('remote')
      assert.is_true(remotes == '' or remotes == '\n')
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

  describe('is_stub_file', function()
    it('returns false for a missing file', function()
      assert.is_false(masterplan.is_stub_file(repo .. '/nope.md'))
    end)

    it('returns true for an empty file', function()
      utils.write_file(repo .. '/empty.md', '')
      assert.is_true(masterplan.is_stub_file(repo .. '/empty.md'))
    end)

    it('returns true for a title-only file', function()
      utils.write_file(repo .. '/title.md', '# title\n\n')
      assert.is_true(masterplan.is_stub_file(repo .. '/title.md'))
    end)

    it('returns false when there is body content', function()
      utils.write_file(repo .. '/body.md', '# title\n\nsome body here\n')
      assert.is_false(masterplan.is_stub_file(repo .. '/body.md'))
    end)

    it('returns false for a file with a non-heading first line', function()
      utils.write_file(repo .. '/raw.md', 'just a note\n')
      assert.is_false(masterplan.is_stub_file(repo .. '/raw.md'))
    end)
  end)

  describe('folder_has_content', function()
    it('returns false for a missing directory', function()
      assert.is_false(masterplan.folder_has_content(repo .. '/nope'))
    end)

    it('returns false for an empty directory', function()
      vim.fn.mkdir(repo .. '/empty', 'p')
      assert.is_false(masterplan.folder_has_content(repo .. '/empty'))
    end)

    it('returns false when every file is a stub', function()
      vim.fn.mkdir(repo .. '/stubs', 'p')
      utils.write_file(repo .. '/stubs/plan.md', '# stub\n')
      utils.write_file(repo .. '/stubs/context.md', '# stub\n\n')
      assert.is_false(masterplan.folder_has_content(repo .. '/stubs'))
    end)

    it('returns true when any file has non-title content', function()
      vim.fn.mkdir(repo .. '/with-body', 'p')
      utils.write_file(repo .. '/with-body/plan.md', '# plan\n')
      utils.write_file(repo .. '/with-body/context.md',
        '# context\n\nmeaningful notes\n')
      assert.is_true(masterplan.folder_has_content(repo .. '/with-body'))
    end)

    it('returns true when a subdirectory exists', function()
      vim.fn.mkdir(repo .. '/nested/sub', 'p')
      utils.write_file(repo .. '/nested/plan.md', '# p\n')
      assert.is_true(masterplan.folder_has_content(repo .. '/nested'))
    end)
  end)

  describe('rewrite_masterplan_line', function()
    it('replaces the plan name in the entry, preserves parens and children', function()
      write_plan(table.concat({
        '# masterplan',
        '',
        '## next plans',
        '- 0003-old-name (some description)',
        '  - a note',
        '    - nested note',
        '- 0004-other',
        '',
      }, '\n'))
      assert.is_true(masterplan.rewrite_masterplan_line(repo,
        '0003-old-name', '0003-new-name'))
      local out = read_plan()
      assert.truthy(out:find('- 0003-new-name (some description)', 1, true))
      assert.truthy(out:find('  - a note', 1, true))
      assert.truthy(out:find('    - nested note', 1, true))
      assert.truthy(out:find('- 0004-other', 1, true))
      assert.is_nil(out:find('0003-old-name', 1, true))
    end)

    it('errors when the plan is not found', function()
      write_plan('## next plans\n- 0001-foo\n')
      local ok, err = masterplan.rewrite_masterplan_line(repo,
        '0099-missing', '0099-new')
      assert.is_false(ok)
      assert.truthy(err:find('not in masterplan', 1, true))
    end)
  end)

  describe('remove_masterplan_entry', function()
    it('drops entry line and its indented children', function()
      write_plan(table.concat({
        '## next plans',
        '- 0001-alpha',
        '  - child note',
        '    - nested note',
        '- 0002-beta',
        '',
      }, '\n'))
      assert.is_true(masterplan.remove_masterplan_entry(repo, '0001-alpha'))
      local out = read_plan()
      assert.is_nil(out:find('0001-alpha', 1, true))
      assert.is_nil(out:find('child note', 1, true))
      assert.is_nil(out:find('nested note', 1, true))
      assert.truthy(out:find('- 0002-beta', 1, true))
    end)

    it('leaves unrelated entries alone', function()
      write_plan(table.concat({
        '## in progress',
        '- 0005-keep-me',
        '',
        '## done',
        '- 0003-old (2026-01-01 00:00:00)',
        '',
      }, '\n'))
      assert.is_true(masterplan.remove_masterplan_entry(repo, '0005-keep-me'))
      local out = read_plan()
      assert.is_nil(out:find('0005-keep-me', 1, true))
      assert.truthy(out:find('- 0003-old', 1, true))
    end)

    it('is a no-op when the plan is not found', function()
      write_plan('## next plans\n- 0001-foo\n')
      assert.is_true(masterplan.remove_masterplan_entry(repo, '9999-ghost'))
      assert.truthy(read_plan():find('- 0001-foo', 1, true))
    end)
  end)

  describe('rename_plan', function()
    local gitrepo = '/tmp/shooter_masterplan_rename_test'
    local mp_path = gitrepo .. '/docs/plans/masterplan.md'
    local shotfiles_plans = gitrepo .. '/docs/shotfiles/docs/plans'

    local function git(...)
      local cmd = { 'git', '-C', gitrepo }
      for _, a in ipairs({ ... }) do table.insert(cmd, a) end
      return vim.fn.system(cmd)
    end

    before_each(function()
      os.execute('rm -rf ' .. gitrepo)
      os.execute('mkdir -p ' .. gitrepo .. '/docs/plans')
      os.execute('mkdir -p ' .. shotfiles_plans)
      vim.fn.system({ 'git', '-C', gitrepo, 'init', '-q' })
      vim.fn.system({ 'git', '-C', gitrepo, 'config', 'user.email', 't@t' })
      vim.fn.system({ 'git', '-C', gitrepo, 'config', 'user.name', 't' })
      vim.fn.system({ 'git', '-C', gitrepo, 'config', 'commit.gpgsign', 'false' })
      vim.fn.system({ 'git', '-C', gitrepo, 'commit', '--allow-empty', '-q', '-m', 'init' })
    end)

    after_each(function()
      os.execute('rm -rf ' .. gitrepo)
    end)

    it('renames folder, shotfile, masterplan entry, and titles', function()
      vim.fn.mkdir(gitrepo .. '/docs/plans/0011-old-slug', 'p')
      utils.write_file(gitrepo .. '/docs/plans/0011-old-slug/plan.md',
        '# 0011-old-slug\n\nplan body\n')
      utils.write_file(gitrepo .. '/docs/plans/0011-old-slug/context.md',
        '# docs/plans/0011-old-slug/context\n\ncontext body\n')
      utils.write_file(shotfiles_plans .. '/0011-old-slug.md',
        '# docs/plans/0011-old-slug\n\nnotes\n')
      utils.write_file(mp_path, table.concat({
        '# masterplan',
        '',
        '## in progress',
        '- 0011-old-slug (some desc)',
        '  - a note',
        '',
      }, '\n'))
      git('add', '-A')
      git('commit', '-q', '-m', 'seed')

      local ok, msg = masterplan.rename_plan(gitrepo,
        '0011-old-slug', '0011-new-slug')
      assert.is_true(ok, msg)
      -- Folder renamed
      assert.is_false(utils.dir_exists(gitrepo .. '/docs/plans/0011-old-slug'))
      assert.is_true(utils.dir_exists(gitrepo .. '/docs/plans/0011-new-slug'))
      -- Shotfile renamed
      assert.is_false(utils.file_exists(shotfiles_plans .. '/0011-old-slug.md'))
      assert.is_true(utils.file_exists(shotfiles_plans .. '/0011-new-slug.md'))
      -- Titles updated
      local plan_body = utils.read_file(
        gitrepo .. '/docs/plans/0011-new-slug/plan.md')
      assert.truthy(plan_body:find('# 0011%-new%-slug'))
      assert.truthy(plan_body:find('plan body', 1, true))
      local ctx_body = utils.read_file(
        gitrepo .. '/docs/plans/0011-new-slug/context.md')
      assert.truthy(ctx_body:find('# docs/plans/0011%-new%-slug/context'))
      local shot_body = utils.read_file(
        shotfiles_plans .. '/0011-new-slug.md')
      assert.truthy(shot_body:find('# docs/plans/0011%-new%-slug'))
      -- Masterplan updated, preserves (desc) + child note
      local mp = utils.read_file(mp_path)
      assert.truthy(mp:find('- 0011-new-slug (some desc)', 1, true))
      assert.truthy(mp:find('  - a note', 1, true))
      assert.is_nil(mp:find('0011-old-slug', 1, true))
      -- Commit landed with rename message
      local subject = git('log', '-1', '--format=%s')
      assert.truthy(subject:find('chore%(plans%): rename 0011%-old%-slug'))
    end)

    it('refuses when the new name already exists as a folder', function()
      vim.fn.mkdir(gitrepo .. '/docs/plans/0001-from', 'p')
      vim.fn.mkdir(gitrepo .. '/docs/plans/0002-to', 'p')
      utils.write_file(mp_path, '## in progress\n- 0001-from\n')
      local ok, err = masterplan.rename_plan(gitrepo, '0001-from', '0002-to')
      assert.is_false(ok)
      assert.truthy(err:find('already exists', 1, true))
    end)

    it('refuses an invalid new name', function()
      vim.fn.mkdir(gitrepo .. '/docs/plans/0001-foo', 'p')
      utils.write_file(mp_path, '## in progress\n- 0001-foo\n')
      local ok, err = masterplan.rename_plan(gitrepo, '0001-foo', 'bad-name')
      assert.is_false(ok)
      assert.truthy(err:find('invalid plan name', 1, true))
    end)

    it('tolerates a missing folder (shotfile-only rename)', function()
      utils.write_file(shotfiles_plans .. '/0003-alpha.md',
        '# docs/plans/0003-alpha\n\nbody\n')
      utils.write_file(mp_path, '## backlog\n- 0003-alpha\n')
      git('add', '-A')
      git('commit', '-q', '-m', 'seed')

      local ok = masterplan.rename_plan(gitrepo, '0003-alpha', '0003-beta')
      assert.is_true(ok)
      assert.is_true(utils.file_exists(shotfiles_plans .. '/0003-beta.md'))
      local mp = utils.read_file(mp_path)
      assert.truthy(mp:find('- 0003-beta', 1, true))
    end)
  end)

  describe('delete_plan', function()
    local gitrepo = '/tmp/shooter_masterplan_delete_test'
    local mp_path = gitrepo .. '/docs/plans/masterplan.md'
    local shotfiles_plans = gitrepo .. '/docs/shotfiles/docs/plans'

    local function git(...)
      local cmd = { 'git', '-C', gitrepo }
      for _, a in ipairs({ ... }) do table.insert(cmd, a) end
      return vim.fn.system(cmd)
    end

    before_each(function()
      os.execute('rm -rf ' .. gitrepo)
      os.execute('mkdir -p ' .. gitrepo .. '/docs/plans')
      os.execute('mkdir -p ' .. shotfiles_plans)
      vim.fn.system({ 'git', '-C', gitrepo, 'init', '-q' })
      vim.fn.system({ 'git', '-C', gitrepo, 'config', 'user.email', 't@t' })
      vim.fn.system({ 'git', '-C', gitrepo, 'config', 'user.name', 't' })
      vim.fn.system({ 'git', '-C', gitrepo, 'config', 'commit.gpgsign', 'false' })
      vim.fn.system({ 'git', '-C', gitrepo, 'commit', '--allow-empty', '-q', '-m', 'init' })
    end)

    after_each(function()
      os.execute('rm -rf ' .. gitrepo)
    end)

    it('deletes folder + shotfile + masterplan entry and commits', function()
      vim.fn.mkdir(gitrepo .. '/docs/plans/0005-goner', 'p')
      utils.write_file(gitrepo .. '/docs/plans/0005-goner/plan.md',
        '# 0005-goner\n\nbody\n')
      utils.write_file(shotfiles_plans .. '/0005-goner.md',
        '# docs/plans/0005-goner\n\nsome notes\n')
      utils.write_file(mp_path, table.concat({
        '## in progress',
        '- 0005-goner (desc)',
        '  - a note',
        '',
      }, '\n'))
      git('add', '-A')
      git('commit', '-q', '-m', 'seed')

      local ok, msg = masterplan.delete_plan(gitrepo, '0005-goner',
        { folder = true, shotfile = true })
      assert.is_true(ok, msg)
      assert.is_false(utils.dir_exists(gitrepo .. '/docs/plans/0005-goner'))
      assert.is_false(utils.file_exists(shotfiles_plans .. '/0005-goner.md'))
      local mp = utils.read_file(mp_path)
      assert.is_nil(mp:find('0005-goner', 1, true))
      local subject = git('log', '-1', '--format=%s')
      assert.truthy(subject:find('chore%(plans%): delete 0005%-goner'))
    end)

    it('keeps masterplan entry when folder stays (shotfile-only delete)', function()
      vim.fn.mkdir(gitrepo .. '/docs/plans/0002-keep-folder', 'p')
      utils.write_file(gitrepo .. '/docs/plans/0002-keep-folder/plan.md',
        '# 0002-keep-folder\n\nvaluable body\n')
      utils.write_file(shotfiles_plans .. '/0002-keep-folder.md',
        '# docs/plans/0002-keep-folder\n\ndisposable notes\n')
      utils.write_file(mp_path, table.concat({
        '## in progress',
        '- 0002-keep-folder',
        '',
      }, '\n'))
      git('add', '-A')
      git('commit', '-q', '-m', 'seed')

      local ok = masterplan.delete_plan(gitrepo, '0002-keep-folder',
        { folder = false, shotfile = true })
      assert.is_true(ok)
      -- Folder untouched
      assert.is_true(utils.dir_exists(gitrepo .. '/docs/plans/0002-keep-folder'))
      -- Masterplan entry remains (fix() may have re-created the shotfile stub)
      local mp = utils.read_file(mp_path)
      assert.truthy(mp:find('- 0002-keep-folder', 1, true))
    end)

    it('drops masterplan entry when folder goes (shotfile untouched)', function()
      vim.fn.mkdir(gitrepo .. '/docs/plans/0009-orphan-shot', 'p')
      utils.write_file(gitrepo .. '/docs/plans/0009-orphan-shot/plan.md',
        '# 0009-orphan-shot\n')
      utils.write_file(shotfiles_plans .. '/0009-orphan-shot.md',
        '# docs/plans/0009-orphan-shot\n\nkeep me\n')
      utils.write_file(mp_path, '## in progress\n- 0009-orphan-shot\n')
      git('add', '-A')
      git('commit', '-q', '-m', 'seed')

      local ok = masterplan.delete_plan(gitrepo, '0009-orphan-shot',
        { folder = true, shotfile = false })
      assert.is_true(ok)
      assert.is_false(utils.dir_exists(gitrepo .. '/docs/plans/0009-orphan-shot'))
      -- Non-stub shotfile with no active same-slug plan is preserved by the
      -- orphan sweep inside fix().
      assert.is_true(utils.file_exists(shotfiles_plans .. '/0009-orphan-shot.md'))
      local mp = utils.read_file(mp_path)
      assert.is_nil(mp:find('0009-orphan-shot', 1, true))
    end)

    it('no-op on disk but still commits masterplan edit when nothing to delete', function()
      -- Plan is only referenced in masterplan; no folder, no shotfile.
      utils.write_file(mp_path, '## in progress\n- 0007-phantom\n')
      git('add', '-A')
      git('commit', '-q', '-m', 'seed')

      local ok = masterplan.delete_plan(gitrepo, '0007-phantom',
        { folder = true, shotfile = true })
      assert.is_true(ok)
      local mp = utils.read_file(mp_path)
      assert.is_nil(mp:find('0007-phantom', 1, true))
    end)
  end)
end)
