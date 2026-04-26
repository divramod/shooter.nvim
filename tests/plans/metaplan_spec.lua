-- Tests for shooter.plans.metaplan
local metaplan = require('shooter.plans.metaplan')
local utils = require('shooter.utils')

describe('shooter.plans.metaplan', function()
  local repo = '/tmp/shooter_metaplan_test'
  local path = repo .. '/docs/plans/metaplan.md'

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
        metaplan.slugify('dev (worktrees, databases, common tools) \\'))
    end)

    it('collapses runs of special chars and trims', function()
      assert.equals('foo-bar-baz', metaplan.slugify('  Foo  &&  BAR / baz!'))
    end)

    it('preserves already-clean slugs', function()
      assert.equals('merge-hal-skills', metaplan.slugify('merge-hal-skills'))
    end)
  end)

  describe('get_title', function()
    it('includes alias from .hal/ALIAS when present', function()
      vim.fn.mkdir(repo .. '/.hal', 'p')
      utils.write_file(repo .. '/.hal/ALIAS', 'shov\n')
      local title = metaplan.get_title(repo)
      -- repo basename is the tail of the path
      local tail = vim.fn.fnamemodify(repo, ':t')
      assert.equals('# metaplan ' .. tail .. ' (shov)', title)
    end)

    it('omits alias when .hal/ALIAS is missing', function()
      local title = metaplan.get_title(repo)
      local tail = vim.fn.fnamemodify(repo, ':t')
      assert.equals('# metaplan ' .. tail, title)
    end)
  end)

  describe('fix (renumbering in ## next plans)', function()
    it('gap-fills, slugifies pre-paren name, preserves parens', function()
      -- Seed docs/plans with a folder at 0004; gap-fill skips it but uses
      -- 0001..0003 first, then 0005, 0006 — committed numbers reserved.
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

      assert.is_true(metaplan.fix(repo))
      local out = read_plan()
      assert.truthy(out:find('- 0001-merge-hal-skills', 1, true))
      assert.truthy(out:find('- 0002-rs-app-fix', 1, true))
      assert.truthy(out:find('- 0003-ts-lib-fix', 1, true))
      assert.truthy(out:find('- 0005-conformity', 1, true))
      assert.truthy(out:find(
        '- 0006-dev (worktrees, databases, common tools)', 1, true))
    end)

    it('strips (description) suffix into the plan shotfile, gap-fills the entry', function()
      -- Folder 0024-seeded reserves 24; entry gap-fills to smallest free (1).
      -- The (agent.md, ...) description is moved to the plan shotfile.
      vim.fn.mkdir(repo .. '/docs/plans/0024-seeded', 'p')
      write_plan(table.concat({
        '## next plans',
        '- 0025-context (agent.md, memory, decisions, instructions)',
        '',
      }, '\n'))
      assert.is_true(metaplan.fix(repo))
      local out = read_plan()
      -- Metaplan entry no longer carries the paren content.
      assert.truthy(out:find('- 0001-context', 1, true))
      assert.is_nil(out:find('agent.md', 1, true))
      -- Plan shotfile gained a `## shot 1` with the paren content as a bullet.
      local shot = utils.read_file(
        repo .. '/docs/plans/0001-context/idea.md')
      assert.truthy(shot:find('## shot 1', 1, true))
      assert.truthy(shot:find('- agent.md, memory, decisions, instructions',
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
      assert.is_true(metaplan.fix(repo))
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
      assert.is_true(metaplan.fix(repo))
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
      assert.is_true(metaplan.fix(repo))
      local out = read_plan()
      assert.truthy(out:find('- 0001-refactoring-04 (2026-04-23 06:12:00)',
        1, true))
    end)

    it('docs/plans folders reserve their numbers from gap-fill', function()
      vim.fn.mkdir(repo .. '/docs/plans/0007-foo', 'p')
      vim.fn.mkdir(repo .. '/docs/plans/0012-bar', 'p')
      write_plan('## next plans\n- alpha\n- beta\n- gamma\n')
      assert.is_true(metaplan.fix(repo))
      local out = read_plan()
      -- 7 and 12 are reserved → entries take 1, 2, 3
      assert.truthy(out:find('- 0001-alpha', 1, true))
      assert.truthy(out:find('- 0002-beta', 1, true))
      assert.truthy(out:find('- 0003-gamma', 1, true))
    end)

    it('in-progress/planned/backlog/done numbers reserve too', function()
      write_plan(table.concat({
        '## in progress',
        '- 0001-active',
        '',
        '## planned',
        '- 0003-coming-soon',
        '',
        '## next plans',
        '- alpha',
        '- beta',
        '',
        '## backlog',
        '- 0005-on-hold',
        '',
        '## done',
        '- 0002-finished (2026-01-01 00:00:00)',
        '',
      }, '\n'))
      assert.is_true(metaplan.fix(repo))
      local out = read_plan()
      -- Reserved: {1, 2, 3, 5}. Smallest free: 4, then 6.
      assert.truthy(out:find('- 0004-alpha', 1, true))
      assert.truthy(out:find('- 0006-beta', 1, true))
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
      assert.is_true(metaplan.fix(repo))
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
      assert.is_true(metaplan.fix(repo))
      local out = read_plan()
      local tail = vim.fn.fnamemodify(repo, ':t')
      assert.truthy(out:find('^# metaplan ' .. tail .. ' %(shov%)'))
    end)

    it('ensures the five sections in canonical order', function()
      write_plan('## done\n- x\n\n## next plans\n- y\n')
      assert.is_true(metaplan.fix(repo))
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
      assert.is_true(metaplan.fix(repo))
      assert.is_nil(read_plan():find('\n\n\n', 1, true))
    end)

    it('creates the file when missing', function()
      assert.is_true(metaplan.fix(repo))
      assert.is_true(utils.file_exists(path))
    end)

    it('keeps `## planned` entries in canonical position; extras move to shotfile', function()
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
      assert.is_true(metaplan.fix(repo))
      local out = read_plan()
      -- Planned entry kept (number unchanged) but paren + child notes moved out
      assert.truthy(out:find('- 0007-future-feature', 1, true))
      assert.is_nil(out:find('with notes', 1, true))
      assert.is_nil(out:find('sub-note that travels with planned entry',
        1, true))
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
      -- next plans gap-fill: reserved {1, 7}. Smallest free is 2.
      assert.truthy(out:find('- 0002-alpha', 1, true))
      -- Planned plan's shotfile carries paren content + child note as bullets.
      local shot = utils.read_file(
        repo .. '/docs/plans/0007-future-feature/idea.md')
      assert.truthy(shot:find('## shot 1', 1, true))
      assert.truthy(shot:find('- with notes', 1, true))
      assert.truthy(shot:find(
        '- sub-note that travels with planned entry', 1, true))
    end)
  end)

  describe('fix (adopt orphan docs/plans folders)', function()
    it('adds docs/plans folders not referenced anywhere into ## in progress', function()
      -- Metaplan has nothing; docs/plans has three folders.
      vim.fn.mkdir(repo .. '/docs/plans/0001-alpha', 'p')
      vim.fn.mkdir(repo .. '/docs/plans/0002-beta', 'p')
      vim.fn.mkdir(repo .. '/docs/plans/0003-gamma', 'p')
      write_plan('## in progress\n\n## next plans\n\n## backlog\n\n## done\n')
      assert.is_true(metaplan.fix(repo))
      local mp = read_plan()
      local ip = mp:match('## in progress\n(.-)\n## planned')
      assert.truthy(ip)
      assert.truthy(ip:find('- 0001-alpha', 1, true))
      assert.truthy(ip:find('- 0002-beta', 1, true))
      assert.truthy(ip:find('- 0003-gamma', 1, true))
    end)

    it('does not adopt folders already in any metaplan section', function()
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
      assert.is_true(metaplan.fix(repo))
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
      assert.is_true(metaplan.fix(repo))
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
      assert.is_true(metaplan.fix(repo))
      assert.is_true(metaplan.fix(repo))
      local mp = read_plan()
      local _, count = mp:gsub('0007%-lonely', '')
      assert.equals(1, count)
    end)
  end)

  describe('fix (idea.md sync + folder rename)', function()
    local plans_dir = repo .. '/docs/plans'

    it('creates idea.md stub for every referenced plan', function()
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
      assert.is_true(metaplan.fix(repo))
      assert.is_true(utils.file_exists(plans_dir .. '/0001-alpha/idea.md'))
      -- Reserved {1,2,3}. beta gap-fills to smallest free (4).
      assert.is_true(utils.file_exists(plans_dir .. '/0004-beta/idea.md'))
      assert.is_true(utils.file_exists(plans_dir .. '/0003-gamma/idea.md'))
      assert.is_true(utils.file_exists(plans_dir .. '/0002-delta/idea.md'))
      -- New files carry the canonical title (docs/plans/<plan>/idea).
      local content = utils.read_file(plans_dir .. '/0004-beta/idea.md')
      assert.truthy(content:find('# docs/plans/0004%-beta/idea'))
    end)

    it('renames a drifted plan FOLDER when next plans is renumbered', function()
      -- Plan folder lives at 0009-merge-hal-skills. Folder 0004-seeded
      -- reserves 4 → gap-fill picks 1 for the next-plans entry, so the
      -- folder must be renamed 0009-* → 0001-*.
      vim.fn.mkdir(plans_dir .. '/0009-merge-hal-skills', 'p')
      utils.write_file(plans_dir .. '/0009-merge-hal-skills/idea.md',
        '# docs/plans/0009-merge-hal-skills/idea\n\nbody\n')
      vim.fn.mkdir(plans_dir .. '/0004-seeded', 'p')
      write_plan('## next plans\n- 0009-merge-hal-skills\n')

      assert.is_true(metaplan.fix(repo))
      assert.is_false(utils.dir_exists(plans_dir .. '/0009-merge-hal-skills'))
      assert.is_true(utils.dir_exists(plans_dir .. '/0001-merge-hal-skills'))
      local content = utils.read_file(
        plans_dir .. '/0001-merge-hal-skills/idea.md')
      assert.truthy(content:find('# docs/plans/0001%-merge%-hal%-skills/idea'))
      assert.truthy(content:find('body', 1, true))
    end)

    it('LOCKED plan (folder has spec.md) is NOT renumbered', function()
      -- 0009-foo has spec.md → locked. Folder 0004-seeded reserves 4. The
      -- locked entry keeps its 0009 even though gap-fill would otherwise
      -- assign 0001.
      vim.fn.mkdir(plans_dir .. '/0009-foo', 'p')
      utils.write_file(plans_dir .. '/0009-foo/spec.md', '# spec\n')
      vim.fn.mkdir(plans_dir .. '/0004-seeded', 'p')
      write_plan('## next plans\n- 0009-foo\n- bar\n')
      assert.is_true(metaplan.fix(repo))
      local mp = read_plan()
      -- 0009-foo stays locked at 0009; bar gap-fills (reserved {4, 9} → 1).
      assert.truthy(mp:find('- 0009-foo', 1, true))
      assert.truthy(mp:find('- 0001-bar', 1, true))
      assert.is_true(utils.dir_exists(plans_dir .. '/0009-foo'))
    end)

    it('leaves an already-correct idea.md in place', function()
      vim.fn.mkdir(plans_dir .. '/0001-alpha', 'p')
      local p = plans_dir .. '/0001-alpha/idea.md'
      utils.write_file(p, '# docs/plans/0001-alpha/idea\n\nnotes\n')
      write_plan('## in progress\n- 0001-alpha\n')

      assert.is_true(metaplan.fix(repo))
      assert.is_true(utils.file_exists(p))
      assert.truthy(utils.read_file(p):find('notes', 1, true))
    end)
  end)

  describe('fix (buffer handling)', function()
    it('updates an open buffer in place', function()
      write_plan('## next plans\n- foo\n- bar\n')
      vim.cmd('edit ' .. vim.fn.fnameescape(path))
      local bufnr = vim.api.nvim_get_current_buf()

      assert.is_true(metaplan.fix(repo))

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
        '# metaplan test',
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
      assert.is_true(metaplan.mark_done(repo, 4))
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
      local ok, err = metaplan.mark_done(repo, 12)
      assert.is_false(ok)
      assert.truthy(err:find('already in done'))
    end)

    it('returns an error when cursor is not on a plan line', function()
      setup_basic()
      -- Line 1 is the title — not a plan entry
      local ok, err = metaplan.mark_done(repo, 1)
      assert.is_false(ok)
      assert.truthy(err)
    end)

    it('creates ## done if it does not exist', function()
      write_plan('## in progress\n- 0001-foo\n')
      assert.is_true(metaplan.mark_done(repo, 2))
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
      assert.is_true(metaplan.mark_done(repo, 2))
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
      assert.is_true(metaplan.mark_done(repo, 2))
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
        metaplan.extract_plan_name('- 0005-merge-hal-skills'))
    end)

    it('ignores trailing (description) and extra text', function()
      assert.equals('0005-merge-hal-skills',
        metaplan.extract_plan_name('- 0005-merge-hal-skills (some notes)'))
    end)

    it('returns nil when the line has no plan reference', function()
      assert.is_nil(metaplan.extract_plan_name('- some plain note'))
      assert.is_nil(metaplan.extract_plan_name(''))
      assert.is_nil(metaplan.extract_plan_name(nil))
    end)

    it('works on indented child note lines (no plan)', function()
      assert.is_nil(metaplan.extract_plan_name('  - a child note'))
    end)
  end)

  describe('edit_plan_at_line', function()
    local function idea(name) return repo .. '/docs/plans/' .. name .. '/idea.md' end

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

    it('opens an existing plan idea.md', function()
      local p = idea('0005-merge-hal-skills')
      vim.fn.mkdir(vim.fn.fnamemodify(p, ':h'), 'p')
      utils.write_file(p, '# docs/plans/0005-merge-hal-skills/idea\n\nbody\n')

      local ok, msg = metaplan.edit_plan_at_line(repo, '- 0005-merge-hal-skills')
      assert.is_true(ok, msg)
      assert.equals('opened', msg)
      local bufname = vim.api.nvim_buf_get_name(0)
      assert.truthy(bufname:find(p, 1, true) or
        (vim.uv.fs_realpath(bufname) or '') == (vim.uv.fs_realpath(p) or p))
    end)

    it('creates plan folder + idea.md stub when none exists', function()
      local target = idea('0007-fresh-plan')
      assert.is_false(utils.file_exists(target))

      local ok, msg = metaplan.edit_plan_at_line(repo, '- 0007-fresh-plan')
      assert.is_true(ok, msg)
      assert.equals('created', msg)
      local content = utils.read_file(target) or ''
      assert.truthy(content:find('# docs/plans/0007%-fresh%-plan/idea'))
    end)

    it('errors when the line has no plan reference', function()
      local ok, err = metaplan.edit_plan_at_line(repo, '  - just a note')
      assert.is_false(ok)
      assert.truthy(err)
    end)
  end)

  describe('new_plan', function()
    it('creates docs/plans/<NNNN-slug>/plan.md with gap-fill', function()
      -- Folder 0004 reserves 4; smallest free is 1.
      vim.fn.mkdir(repo .. '/docs/plans/0004-seeded', 'p')
      local ok, path = metaplan.new_plan(repo, 'My Fresh Plan')
      assert.is_true(ok, path)
      assert.equals(repo .. '/docs/plans/0001-my-fresh-plan/plan.md', path)
      assert.is_true(utils.file_exists(path))
      local content = utils.read_file(path) or ''
      assert.truthy(content:find('^# 0001%-my%-fresh%-plan'))
    end)

    it('starts at 0001 when docs/plans is empty', function()
      local ok, path = metaplan.new_plan(repo, 'first one')
      assert.is_true(ok)
      assert.equals(repo .. '/docs/plans/0001-first-one/plan.md', path)
    end)

    it('also considers metaplan sections when picking the next number', function()
      -- ## done at 0020 reserves 20; smallest free is 1.
      write_plan('## done\n- 0020-stuff (2026-01-01 00:00:00)\n')
      local ok, path = metaplan.new_plan(repo, 'alpha')
      assert.is_true(ok)
      assert.equals(repo .. '/docs/plans/0001-alpha/plan.md', path)
    end)

    it('refuses an empty or whitespace title', function()
      local ok1, err1 = metaplan.new_plan(repo, '')
      assert.is_false(ok1); assert.truthy(err1)
      local ok2, err2 = metaplan.new_plan(repo, '   ')
      assert.is_false(ok2); assert.truthy(err2)
    end)

    it('appends the plan to ## next plans in metaplan.md', function()
      write_plan('## in progress\n- 0002-current\n')
      local ok = metaplan.new_plan(repo, 'fresh')
      assert.is_true(ok)
      local mp = read_plan()
      -- Reserved {2}; smallest free is 1; entry lands in next plans.
      assert.truthy(mp:find('## next plans', 1, true))
      local np = mp:match('## next plans.-\n(.-)\n##')
      assert.truthy(np and np:find('- 0001-fresh', 1, true))
    end)

    it('runs fix(): folder and metaplan number stay in sync', function()
      vim.fn.mkdir(repo .. '/docs/plans/0004-seeded', 'p')
      write_plan('## done\n- 0003-old (2026-01-01 00:00:00)\n')
      local ok, path = metaplan.new_plan(repo, 'alpha')
      assert.is_true(ok)
      -- Reserved {3, 4}; smallest free is 1.
      assert.equals(repo .. '/docs/plans/0001-alpha/plan.md', path)

      local mp = read_plan()
      assert.truthy(mp:find('- 0001-alpha', 1, true))
      -- No drift between folder name and metaplan entry.
      assert.is_nil(mp:find('- 0002-alpha', 1, true))

      -- Plan shotfile was synced.
      assert.is_true(utils.file_exists(
        repo .. '/docs/plans/0001-alpha/idea.md'))
    end)

    it('does not duplicate the entry when run twice with the same title', function()
      assert.is_true(metaplan.new_plan(repo, 'twice'))
      assert.is_true(metaplan.new_plan(repo, 'twice'))
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

  describe('collect_used_numbers', function()
    it('ignores docs/plans folders that match `## next plans` entries', function()
      vim.fn.mkdir(repo .. '/docs/plans/0004-seeded', 'p')
      vim.fn.mkdir(repo .. '/docs/plans/0007-future', 'p')
      local parsed = metaplan.parse(table.concat({
        '## in progress', '- 0004-seeded',
        '## next plans', '- 0007-future',
        '## backlog', '',
        '## done', '',
      }, '\n'))
      local used = metaplan.collect_used_numbers(repo, parsed.sections)
      assert.is_true(used[4])
      -- 0007-future is a tentative next-plans placeholder → not committed.
      assert.is_nil(used[7])
    end)

    it('includes `## planned` entries', function()
      local parsed = metaplan.parse(table.concat({
        '## in progress', '- 0002-active',
        '## planned', '- 0011-coming-next',
        '## next plans', '',
        '## backlog', '',
        '## done', '',
      }, '\n'))
      local used = metaplan.collect_used_numbers(repo, parsed.sections)
      assert.is_true(used[2])
      assert.is_true(used[11])
    end)
  end)

  describe('next_free_plan_number', function()
    it('returns the smallest free number using gap-fill', function()
      -- Folder 0002 + done 0003 reserve {2,3}. Existing next plans entry
      -- (0005-bar) takes the smallest free (1) under render's gap-fill, so
      -- the NEW entry that new_plan would append next gets 4 (smallest free
      -- after 1 is taken).
      vim.fn.mkdir(repo .. '/docs/plans/0002-foo', 'p')
      local parsed = metaplan.parse(table.concat({
        '## next plans', '- 0005-bar',
        '## done', '- 0003-baz (2026-01-01 00:00:00)',
      }, '\n'))
      assert.equals(4, metaplan.next_free_plan_number(repo, parsed.sections))
    end)
  end)

  describe('next_plans_number_at', function()
    it('returns smallest N where exactly k-1 smaller numbers are also free', function()
      local mp = metaplan
      assert.equals(1, mp.next_plans_number_at({}, 1))
      assert.equals(2, mp.next_plans_number_at({}, 2))
      -- {2, 3} reserved → free seq: 1, 4, 5, ...
      assert.equals(1, mp.next_plans_number_at({ [2]=true, [3]=true }, 1))
      assert.equals(4, mp.next_plans_number_at({ [2]=true, [3]=true }, 2))
      assert.equals(5, mp.next_plans_number_at({ [2]=true, [3]=true }, 3))
      -- Defaults k=1 when nil/zero.
      assert.equals(1, mp.next_plans_number_at({}, nil))
      assert.equals(1, mp.next_plans_number_at({}, 0))
    end)
  end)

  describe('list_worktree_roots', function()
    local gitrepo = '/tmp/shooter_metaplan_wtroots_test'
    local wt2 = '/tmp/shooter_metaplan_wtroots_test_wt2'

    before_each(function()
      os.execute('rm -rf ' .. gitrepo .. ' ' .. wt2)
      os.execute('mkdir -p ' .. gitrepo)
      vim.fn.system({ 'git', '-C', gitrepo, 'init', '-q', '-b', 'main' })
      vim.fn.system({ 'git', '-C', gitrepo, 'config', 'user.email', 't@t' })
      vim.fn.system({ 'git', '-C', gitrepo, 'config', 'user.name', 't' })
      vim.fn.system({ 'git', '-C', gitrepo, 'config', 'commit.gpgsign', 'false' })
      vim.fn.system({ 'git', '-C', gitrepo, 'commit', '--allow-empty', '-q', '-m', 'init' })
    end)

    after_each(function()
      os.execute('rm -rf ' .. gitrepo .. ' ' .. wt2)
    end)

    it('returns just git_root when no extra worktrees', function()
      local roots = metaplan.list_worktree_roots(gitrepo)
      assert.equals(1, #roots)
      assert.equals(vim.uv.fs_realpath(gitrepo) or gitrepo, roots[1])
    end)

    it('returns all worktrees including secondaries', function()
      vim.fn.system({ 'git', '-C', gitrepo, 'worktree', 'add', '-b', 'wt2', wt2 })
      local roots = metaplan.list_worktree_roots(gitrepo)
      assert.equals(2, #roots)
      local resolved = {}
      for _, r in ipairs(roots) do resolved[r] = true end
      assert.is_true(resolved[vim.uv.fs_realpath(gitrepo) or gitrepo])
      assert.is_true(resolved[vim.uv.fs_realpath(wt2) or wt2])
    end)

    it('falls back to {git_root} when git fails', function()
      assert.same({}, metaplan.list_worktree_roots(nil))
      assert.same({}, metaplan.list_worktree_roots(''))
      -- Non-git directory: git command errors → fallback path.
      local nogit = '/tmp/shooter_not_a_repo_xyz'
      os.execute('rm -rf ' .. nogit .. ' && mkdir -p ' .. nogit)
      assert.same({ nogit }, metaplan.list_worktree_roots(nogit))
      os.execute('rm -rf ' .. nogit)
    end)
  end)

  describe('extract_extras', function()
    it('returns nil paren and empty notes when entry has neither', function()
      local p, n, c, had = metaplan.extract_extras({
        text = '0001-foo', children = {} })
      assert.is_nil(p)
      assert.same({}, n)
      assert.equals('0001-foo', c)
      assert.is_false(had)
    end)

    it('extracts paren content and dedents one level of children', function()
      local p, n, c, had = metaplan.extract_extras({
        text = '0001-foo (some desc)',
        children = {
          '  - first note',
          '    - nested kept indented',
          '  - second note',
        },
      })
      assert.equals('some desc', p)
      assert.same({ '- first note', '  - nested kept indented',
        '- second note' }, n)
      assert.equals('0001-foo', c)
      assert.is_true(had)
    end)

    it('preserves a trailing (timestamp) on done entries', function()
      local p, _, c = metaplan.extract_extras({
        text = '0001-foo (some desc) (2026-04-23 06:12:00)',
        children = {} })
      assert.equals('some desc', p)
      assert.equals('0001-foo (2026-04-23 06:12:00)', c)
    end)

    it('does NOT extract a sole timestamp paren (treats as metadata)', function()
      local p, _, c, had = metaplan.extract_extras({
        text = '0001-foo (2026-04-23 06:12:00)',
        children = {} })
      assert.is_nil(p)
      assert.equals('0001-foo (2026-04-23 06:12:00)', c)
      assert.is_false(had)
    end)

    it('extracts only child notes when there is no paren', function()
      local p, n, c, had = metaplan.extract_extras({
        text = '0002-bar',
        children = { '  - just a note' },
      })
      assert.is_nil(p)
      assert.same({ '- just a note' }, n)
      assert.equals('0002-bar', c)
      assert.is_true(had)
    end)
  end)

  describe('apply_extras_to_idea', function()
    local plan = '0042-feature-parity'
    local shot_path = repo .. '/docs/plans/' .. plan .. '/idea.md'

    local function read_shot()
      return utils.read_file(shot_path) or ''
    end

    it('creates ## shot 1 when the file has only a title', function()
      assert.is_true(metaplan.apply_extras_to_idea(repo, plan,
        'somethin here', { '- every feature implemented in api tui swift kotlin next' }))
      local body = read_shot()
      assert.truthy(body:find('## shot 1', 1, true))
      assert.truthy(body:find('- somethin here', 1, true))
      assert.truthy(body:find(
        '- every feature implemented in api tui swift kotlin next', 1, true))
      -- Title preserved.
      assert.truthy(body:find('# docs/plans/0042%-feature%-parity'))
    end)

    it('appends to an existing open ## shot 1', function()
      vim.fn.mkdir(repo .. '/docs/plans/' .. plan, 'p')
      utils.write_file(shot_path, table.concat({
        '# docs/plans/' .. plan,
        '',
        '## shot 1',
        '- pre-existing bullet',
        '',
      }, '\n'))
      assert.is_true(metaplan.apply_extras_to_idea(repo, plan,
        'new desc', {}))
      local body = read_shot()
      -- Both bullets live under shot 1, in original-then-new order
      local idx_old = body:find('- pre-existing bullet', 1, true)
      local idx_new = body:find('- new desc', 1, true)
      assert.is_true(idx_old < idx_new)
      -- No new shot 2 was created
      assert.is_nil(body:find('## shot 2', 1, true))
    end)

    it('creates a new ## shot N above a shooted ## x shot N-1', function()
      vim.fn.mkdir(repo .. '/docs/plans/' .. plan, 'p')
      utils.write_file(shot_path, table.concat({
        '# docs/plans/' .. plan,
        '',
        '## x shot 1 folder structure (2026-04-23 06:48:43)',
        '- old bullet',
        '',
      }, '\n'))
      assert.is_true(metaplan.apply_extras_to_idea(repo, plan,
        'fresh extras', {}))
      local body = read_shot()
      local idx_new = body:find('## shot 2', 1, true)
      local idx_old = body:find('## x shot 1', 1, true)
      assert.is_truthy(idx_new)
      assert.is_truthy(idx_old)
      -- New shot is ABOVE the shooted one
      assert.is_true(idx_new < idx_old)
      assert.truthy(body:find('- fresh extras', 1, true))
    end)

    it('is a no-op when both paren and notes are empty', function()
      vim.fn.mkdir(repo .. '/docs/plans/' .. plan, 'p')
      utils.write_file(shot_path, '# docs/plans/' .. plan .. '/idea\n\n')
      assert.is_true(metaplan.apply_extras_to_idea(repo, plan, nil, {}))
      assert.equals('# docs/plans/' .. plan .. '/idea\n\n', read_shot())
    end)
  end)

  describe('fix (extras → plan shotfile)', function()
    it('moves paren and child notes into ## shot 1 and cleans metaplan', function()
      write_plan(table.concat({
        '## next plans',
        '- 0001-feature-parity (somethin here)',
        '  - every feature in api tui swift kotlin next',
        '',
      }, '\n'))
      assert.is_true(metaplan.fix(repo))
      local mp = read_plan()
      -- Metaplan: only the bare entry remains.
      assert.truthy(mp:find('- 0001-feature-parity', 1, true))
      assert.is_nil(mp:find('somethin here', 1, true))
      assert.is_nil(mp:find('every feature in api tui', 1, true))
      -- Shotfile: shot 1 with the moved bullets.
      local shot = utils.read_file(
        repo .. '/docs/plans/0001-feature-parity/idea.md')
      assert.truthy(shot:find('## shot 1', 1, true))
      assert.truthy(shot:find('- somethin here', 1, true))
      assert.truthy(shot:find('- every feature in api tui swift kotlin next',
        1, true))
    end)

    it('is a no-op when metaplan plans have no parens or notes', function()
      write_plan('## in progress\n- 0001-bare\n')
      assert.is_true(metaplan.fix(repo))
      assert.is_true(metaplan.fix(repo))  -- second pass stays clean
      local mp = read_plan()
      assert.truthy(mp:find('- 0001-bare', 1, true))
      -- Shotfile is title-only stub (no shots created).
      local shot = utils.read_file(
        repo .. '/docs/plans/0001-bare/idea.md') or ''
      assert.is_nil(shot:find('## shot ', 1, true))
    end)

    it('appends to existing open shot when user re-adds parens later', function()
      -- First pass: extracts (one) into the new shot 1.
      write_plan('## in progress\n- 0001-foo (one)\n')
      assert.is_true(metaplan.fix(repo))
      local shot_path = repo .. '/docs/plans/0001-foo/idea.md'
      assert.truthy(utils.read_file(shot_path):find('- one', 1, true))
      -- User re-adds parens to the same plan.
      write_plan('## in progress\n- 0001-foo (two)\n')
      assert.is_true(metaplan.fix(repo))
      local shot = utils.read_file(shot_path) or ''
      -- Both bullets live under a single shot 1.
      assert.truthy(shot:find('- one', 1, true))
      assert.truthy(shot:find('- two', 1, true))
      assert.is_nil(shot:find('## shot 2', 1, true))
    end)

    it('creates shot 2 above a shooted shot 1 when extras come back', function()
      vim.fn.mkdir(repo .. '/docs/plans/0001-foo', 'p')
      utils.write_file(repo
        .. '/docs/plans/0001-foo/idea.md', table.concat({
          '# docs/plans/0001-foo/idea',
          '',
          '## x shot 1 folder structure (2026-04-23 06:48:43)',
          '- old bullet',
          '',
        }, '\n'))
      write_plan('## in progress\n- 0001-foo (new desc)\n')
      assert.is_true(metaplan.fix(repo))
      local shot = utils.read_file(
        repo .. '/docs/plans/0001-foo/idea.md') or ''
      local idx_new = shot:find('## shot 2', 1, true)
      local idx_old = shot:find('## x shot 1', 1, true)
      assert.is_truthy(idx_new)
      assert.is_truthy(idx_old)
      assert.is_true(idx_new < idx_old)
      assert.truthy(shot:find('- new desc', 1, true))
    end)

    it('preserves done timestamp; only description moves', function()
      write_plan(table.concat({
        '## done',
        '- 0001-cleanup (description here) (2026-04-23 06:12:00)',
        '',
      }, '\n'))
      assert.is_true(metaplan.fix(repo))
      local mp = read_plan()
      -- Timestamp preserved, description gone.
      assert.truthy(mp:find('- 0001-cleanup (2026-04-23 06:12:00)', 1, true))
      assert.is_nil(mp:find('description here', 1, true))
      -- Shotfile got the description.
      local shot = utils.read_file(
        repo .. '/docs/plans/0001-cleanup/idea.md')
      assert.truthy(shot:find('- description here', 1, true))
    end)

    it('processes plans across all sections in one pass', function()
      write_plan(table.concat({
        '## in progress',
        '- 0001-active (alpha)',
        '',
        '## planned',
        '- 0002-soon',
        '  - sub note for soon',
        '',
        '## next plans',
        '- 0003-tentative (beta)',
        '',
      }, '\n'))
      assert.is_true(metaplan.fix(repo))
      local d = repo .. '/docs/plans'
      assert.truthy(utils.read_file(d .. '/0001-active/idea.md'):find(
        '- alpha', 1, true))
      assert.truthy(utils.read_file(d .. '/0002-soon/idea.md'):find(
        '- sub note for soon', 1, true))
      assert.truthy(utils.read_file(d .. '/0003-tentative/idea.md'):find(
        '- beta', 1, true))
      -- Metaplan no longer contains any extras.
      local mp = read_plan()
      assert.is_nil(mp:find('alpha', 1, true))
      assert.is_nil(mp:find('beta', 1, true))
      assert.is_nil(mp:find('sub note for soon', 1, true))
    end)
  end)

  describe('fix (worktree-aware gap-fill)', function()
    local gitrepo = '/tmp/shooter_metaplan_wtfix_test'
    local wt2 = '/tmp/shooter_metaplan_wtfix_test_wt2'
    local mp_path = gitrepo .. '/docs/plans/metaplan.md'

    before_each(function()
      os.execute('rm -rf ' .. gitrepo .. ' ' .. wt2)
      os.execute('mkdir -p ' .. gitrepo)
      vim.fn.system({ 'git', '-C', gitrepo, 'init', '-q', '-b', 'main' })
      vim.fn.system({ 'git', '-C', gitrepo, 'config', 'user.email', 't@t' })
      vim.fn.system({ 'git', '-C', gitrepo, 'config', 'user.name', 't' })
      vim.fn.system({ 'git', '-C', gitrepo, 'config', 'commit.gpgsign', 'false' })
      vim.fn.system({ 'git', '-C', gitrepo, 'commit', '--allow-empty', '-q', '-m', 'init' })
    end)

    after_each(function()
      os.execute('rm -rf ' .. gitrepo .. ' ' .. wt2)
    end)

    it('treats folders in other worktrees as committed (the user\'s case)', function()
      -- Reproduce the user's hal scenario: main has 0001..0014 as folders,
      -- a worktree has 0016, and 0015 is the only gap below max → fill it.
      for i = 1, 14 do
        vim.fn.mkdir(gitrepo
          .. string.format('/docs/plans/%04d-seeded-%d', i, i), 'p')
      end
      utils.write_file(mp_path, table.concat({
        '## in progress',
        '- 0014-seeded-14',
        '- 0016-fix-lifecycle-commands-and-skills',
        '',
        '## next plans',
        '- 0017-refactore-doctor-and-envfile',
        '- 0018-app-and-lib-improvements',
        '',
      }, '\n'))
      vim.fn.system({ 'git', '-C', gitrepo, 'worktree', 'add', '-b', 'wt2', wt2 })
      vim.fn.mkdir(wt2 .. '/docs/plans/0016-fix-lifecycle-commands-and-skills', 'p')

      assert.is_true(metaplan.fix(gitrepo))
      local mp = utils.read_file(mp_path)
      -- Reserved {1..14, 16}. First gap is 15, then 17, 18, ...
      -- First next-plans entry fills the 0015 gap.
      assert.truthy(mp:find('- 0015-refactore-doctor-and-envfile', 1, true))
      -- Second entry continues at 0017 (16 reserved by worktree folder).
      assert.truthy(mp:find('- 0017-app-and-lib-improvements', 1, true))
    end)

    it('a worktree folder alone reserves its number', function()
      -- Main worktree's docs/plans empty; wt2 has folder 0005-foo. Single
      -- next-plans entry should skip 5 (worktree reserved it), NOT take it.
      vim.fn.mkdir(gitrepo .. '/docs/plans', 'p')
      utils.write_file(mp_path, '## next plans\n- alpha\n')
      vim.fn.system({ 'git', '-C', gitrepo, 'worktree', 'add', '-b', 'wt2', wt2 })
      vim.fn.mkdir(wt2 .. '/docs/plans/0005-foo', 'p')

      assert.is_true(metaplan.fix(gitrepo))
      local mp = utils.read_file(mp_path)
      -- Reserved {5}. Smallest free is 1.
      assert.truthy(mp:find('- 0001-alpha', 1, true))
      -- And NOT 5
      assert.is_nil(mp:find('- 0005-alpha', 1, true))
    end)
  end)

  describe('commit_plans', function()
    local gitrepo = '/tmp/shooter_metaplan_commit_test'
    local mp_path = gitrepo .. '/docs/plans/metaplan.md'
    local shotfiles_plans = gitrepo .. '/docs/plans'

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

    it('commits changes under docs/plans (metaplan + plan folders)', function()
      utils.write_file(mp_path, '# metaplan\n')
      vim.fn.mkdir(gitrepo .. '/docs/plans/0001-foo', 'p')
      utils.write_file(gitrepo .. '/docs/plans/0001-foo/idea.md',
        '# docs/plans/0001-foo/idea\n')

      local before = count_commits()
      local ok, msg, committed = metaplan.commit_plans(gitrepo)
      assert.is_true(ok, msg)
      assert.is_true(committed)
      assert.equals(before + 1, count_commits())

      local files_in_commit = git('show', '--name-only', '--format=', 'HEAD')
      assert.truthy(files_in_commit:find('docs/plans/metaplan%.md'))
      assert.truthy(files_in_commit:find('docs/plans/0001%-foo/idea%.md'))

      local subject = git('log', '-1', '--format=%s')
      assert.truthy(subject:find('chore%(plans%): sync'))
    end)

    it('reports no changes when plan folders are clean', function()
      utils.write_file(mp_path, '# metaplan\n')
      git('add', '-A', '--', 'docs/plans')
      git('commit', '-q', '-m', 'seed')

      local before = count_commits()
      local ok, msg, committed = metaplan.commit_plans(gitrepo)
      assert.is_true(ok)
      assert.is_false(committed)
      assert.truthy(msg:find('nothing to commit', 1, true))
      assert.equals(before, count_commits())
    end)

    it('leaves unrelated staged changes out of the commit', function()
      utils.write_file(mp_path, '# metaplan\n')
      utils.write_file(gitrepo .. '/other.txt', 'hello\n')
      git('add', 'other.txt')

      local ok, _, committed = metaplan.commit_plans(gitrepo)
      assert.is_true(ok); assert.is_true(committed)

      local files_in_commit = git('show', '--name-only', '--format=', 'HEAD')
      assert.truthy(files_in_commit:find('docs/plans/metaplan%.md'))
      assert.is_nil(files_in_commit:find('other%.txt'))
      -- And other.txt is still staged
      local staged = git('diff', '--cached', '--name-only')
      assert.truthy(staged:find('other.txt'))
    end)

    it('no-op and no-error when docs/plans does not exist', function()
      os.execute('rm -rf ' .. gitrepo .. '/docs/plans')
      local ok, msg, committed = metaplan.commit_plans(gitrepo)
      assert.is_true(ok)
      assert.is_false(committed)
      assert.truthy(msg:find('no folders', 1, true))
    end)

    it('does not push (no remote ever contacted)', function()
      -- If commit_plans tried to push, `git log origin/main` would reflect it.
      -- Easier assertion: no `origin` remote was added and no push ran.
      utils.write_file(mp_path, '# metaplan\n')
      metaplan.commit_plans(gitrepo)
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
      local ok, msg = metaplan.open_plan_file(repo,
        '- 0005-merge-hal-skills', 'plan')
      assert.is_true(ok, msg)
      assert.equals('opened', msg)
      local bufname = vim.api.nvim_buf_get_name(0)
      assert.truthy(bufname:find('plan.md', 1, true))
    end)

    it('opens docs/plans/<plan>/context.md', function()
      vim.fn.mkdir(plan_dir, 'p')
      utils.write_file(plan_dir .. '/context.md', '# context\n')
      local ok = metaplan.open_plan_file(repo,
        '- 0005-merge-hal-skills', 'context')
      assert.is_true(ok)
      assert.truthy(vim.api.nvim_buf_get_name(0):find('context.md', 1, true))
    end)

    it('opens docs/plans/<plan>/spec.md', function()
      vim.fn.mkdir(plan_dir, 'p')
      utils.write_file(plan_dir .. '/spec.md', '# spec\n')
      local ok = metaplan.open_plan_file(repo,
        '- 0005-merge-hal-skills', 'spec')
      assert.is_true(ok)
      assert.truthy(vim.api.nvim_buf_get_name(0):find('spec.md', 1, true))
    end)

    it('opens docs/plans/<plan>/masterplan.md', function()
      vim.fn.mkdir(plan_dir, 'p')
      utils.write_file(plan_dir .. '/masterplan.md', '# masterplan\n')
      local ok = metaplan.open_plan_file(repo,
        '- 0005-merge-hal-skills', 'masterplan')
      assert.is_true(ok)
      assert.truthy(vim.api.nvim_buf_get_name(0):find('masterplan.md', 1, true))
    end)

    it('reports missing file when masterplan.md does not exist', function()
      vim.fn.mkdir(plan_dir, 'p')
      local ok, err = metaplan.open_plan_file(repo,
        '- 0005-merge-hal-skills', 'masterplan')
      assert.is_false(ok)
      assert.truthy(err:find('no masterplan.md for 0005-merge-hal-skills',
        1, true))
    end)

    it('reports no plan on line when cursor line has no plan reference', function()
      local ok, err = metaplan.open_plan_file(repo, '  - a child note', 'plan')
      assert.is_false(ok)
      assert.truthy(err:find('no plan on current line', 1, true))
    end)

    it('reports missing file when the specific kind does not exist', function()
      vim.fn.mkdir(plan_dir, 'p')
      utils.write_file(plan_dir .. '/plan.md', '# plan\n')
      local ok, err = metaplan.open_plan_file(repo,
        '- 0005-merge-hal-skills', 'spec')
      assert.is_false(ok)
      assert.truthy(err:find('no spec.md for 0005-merge-hal-skills', 1, true))
    end)

    it('reports missing file when the plan folder does not exist', function()
      local ok, err = metaplan.open_plan_file(repo,
        '- 0099-missing-plan', 'plan')
      assert.is_false(ok)
      assert.truthy(err:find('no plan.md for 0099-missing-plan', 1, true))
    end)

    it('rejects an invalid kind', function()
      local ok, err = metaplan.open_plan_file(repo,
        '- 0005-merge-hal-skills', 'readme')
      assert.is_false(ok)
      assert.truthy(err:find('invalid kind', 1, true))
    end)
  end)

  describe('is_stub_file', function()
    it('returns false for a missing file', function()
      assert.is_false(metaplan.is_stub_file(repo .. '/nope.md'))
    end)

    it('returns true for an empty file', function()
      utils.write_file(repo .. '/empty.md', '')
      assert.is_true(metaplan.is_stub_file(repo .. '/empty.md'))
    end)

    it('returns true for a title-only file', function()
      utils.write_file(repo .. '/title.md', '# title\n\n')
      assert.is_true(metaplan.is_stub_file(repo .. '/title.md'))
    end)

    it('returns false when there is body content', function()
      utils.write_file(repo .. '/body.md', '# title\n\nsome body here\n')
      assert.is_false(metaplan.is_stub_file(repo .. '/body.md'))
    end)

    it('returns false for a file with a non-heading first line', function()
      utils.write_file(repo .. '/raw.md', 'just a note\n')
      assert.is_false(metaplan.is_stub_file(repo .. '/raw.md'))
    end)
  end)

  describe('folder_has_content', function()
    it('returns false for a missing directory', function()
      assert.is_false(metaplan.folder_has_content(repo .. '/nope'))
    end)

    it('returns false for an empty directory', function()
      vim.fn.mkdir(repo .. '/empty', 'p')
      assert.is_false(metaplan.folder_has_content(repo .. '/empty'))
    end)

    it('returns false when every file is a stub', function()
      vim.fn.mkdir(repo .. '/stubs', 'p')
      utils.write_file(repo .. '/stubs/plan.md', '# stub\n')
      utils.write_file(repo .. '/stubs/context.md', '# stub\n\n')
      assert.is_false(metaplan.folder_has_content(repo .. '/stubs'))
    end)

    it('returns true when any file has non-title content', function()
      vim.fn.mkdir(repo .. '/with-body', 'p')
      utils.write_file(repo .. '/with-body/plan.md', '# plan\n')
      utils.write_file(repo .. '/with-body/context.md',
        '# context\n\nmeaningful notes\n')
      assert.is_true(metaplan.folder_has_content(repo .. '/with-body'))
    end)

    it('returns true when a subdirectory exists', function()
      vim.fn.mkdir(repo .. '/nested/sub', 'p')
      utils.write_file(repo .. '/nested/plan.md', '# p\n')
      assert.is_true(metaplan.folder_has_content(repo .. '/nested'))
    end)
  end)

  describe('rewrite_metaplan_line', function()
    it('replaces the plan name in the entry, preserves parens and children', function()
      write_plan(table.concat({
        '# metaplan',
        '',
        '## next plans',
        '- 0003-old-name (some description)',
        '  - a note',
        '    - nested note',
        '- 0004-other',
        '',
      }, '\n'))
      assert.is_true(metaplan.rewrite_metaplan_line(repo,
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
      local ok, err = metaplan.rewrite_metaplan_line(repo,
        '0099-missing', '0099-new')
      assert.is_false(ok)
      assert.truthy(err:find('not in metaplan', 1, true))
    end)
  end)

  describe('remove_metaplan_entry', function()
    it('drops entry line and its indented children', function()
      write_plan(table.concat({
        '## next plans',
        '- 0001-alpha',
        '  - child note',
        '    - nested note',
        '- 0002-beta',
        '',
      }, '\n'))
      assert.is_true(metaplan.remove_metaplan_entry(repo, '0001-alpha'))
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
      assert.is_true(metaplan.remove_metaplan_entry(repo, '0005-keep-me'))
      local out = read_plan()
      assert.is_nil(out:find('0005-keep-me', 1, true))
      assert.truthy(out:find('- 0003-old', 1, true))
    end)

    it('is a no-op when the plan is not found', function()
      write_plan('## next plans\n- 0001-foo\n')
      assert.is_true(metaplan.remove_metaplan_entry(repo, '9999-ghost'))
      assert.truthy(read_plan():find('- 0001-foo', 1, true))
    end)
  end)

  describe('rename_plan', function()
    local gitrepo = '/tmp/shooter_metaplan_rename_test'
    local mp_path = gitrepo .. '/docs/plans/metaplan.md'
    local shotfiles_plans = gitrepo .. '/docs/plans'

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

    it('renames folder (incl. plan/context/spec/idea), metaplan entry, titles', function()
      vim.fn.mkdir(gitrepo .. '/docs/plans/0011-old-slug', 'p')
      utils.write_file(gitrepo .. '/docs/plans/0011-old-slug/plan.md',
        '# 0011-old-slug\n\nplan body\n')
      utils.write_file(gitrepo .. '/docs/plans/0011-old-slug/context.md',
        '# docs/plans/0011-old-slug/context\n\ncontext body\n')
      utils.write_file(gitrepo .. '/docs/plans/0011-old-slug/idea.md',
        '# docs/plans/0011-old-slug/idea\n\nnotes\n')
      utils.write_file(mp_path, table.concat({
        '# metaplan',
        '',
        '## in progress',
        '- 0011-old-slug (some desc)',
        '  - a note',
        '',
      }, '\n'))
      git('add', '-A')
      git('commit', '-q', '-m', 'seed')

      local ok, msg = metaplan.rename_plan(gitrepo,
        '0011-old-slug', '0011-new-slug')
      assert.is_true(ok, msg)
      -- Folder renamed (carries every kind file along)
      assert.is_false(utils.dir_exists(gitrepo .. '/docs/plans/0011-old-slug'))
      assert.is_true(utils.dir_exists(gitrepo .. '/docs/plans/0011-new-slug'))
      -- Titles updated everywhere to the canonical # docs/plans/<plan>/<kind>
      local plan_body = utils.read_file(
        gitrepo .. '/docs/plans/0011-new-slug/plan.md')
      assert.truthy(plan_body:find('# docs/plans/0011%-new%-slug/plan'))
      assert.truthy(plan_body:find('plan body', 1, true))
      local ctx_body = utils.read_file(
        gitrepo .. '/docs/plans/0011-new-slug/context.md')
      assert.truthy(ctx_body:find('# docs/plans/0011%-new%-slug/context'))
      local idea_body = utils.read_file(
        gitrepo .. '/docs/plans/0011-new-slug/idea.md')
      assert.truthy(idea_body:find('# docs/plans/0011%-new%-slug/idea'))
      assert.truthy(idea_body:find('notes', 1, true))
      -- Metaplan updated, but extras (paren + child note) move into idea.md
      -- via fix() running inside rename_plan's commit pass — except
      -- rename_plan does NOT run fix(). Confirm raw rewrite kept the line.
      local mp = utils.read_file(mp_path)
      assert.truthy(mp:find('- 0011-new-slug (some desc)', 1, true))
      assert.is_nil(mp:find('0011-old-slug', 1, true))
      -- Commit landed with rename message
      local subject = git('log', '-1', '--format=%s')
      assert.truthy(subject:find('chore%(plans%): rename 0011%-old%-slug'))
    end)

    it('refuses when the new name already exists as a folder', function()
      vim.fn.mkdir(gitrepo .. '/docs/plans/0001-from', 'p')
      vim.fn.mkdir(gitrepo .. '/docs/plans/0002-to', 'p')
      utils.write_file(mp_path, '## in progress\n- 0001-from\n')
      local ok, err = metaplan.rename_plan(gitrepo, '0001-from', '0002-to')
      assert.is_false(ok)
      assert.truthy(err:find('already exists', 1, true))
    end)

    it('refuses an invalid new name', function()
      vim.fn.mkdir(gitrepo .. '/docs/plans/0001-foo', 'p')
      utils.write_file(mp_path, '## in progress\n- 0001-foo\n')
      local ok, err = metaplan.rename_plan(gitrepo, '0001-foo', 'bad-name')
      assert.is_false(ok)
      assert.truthy(err:find('invalid plan name', 1, true))
    end)

    it('tolerates a missing folder (metaplan-line-only rename)', function()
      utils.write_file(mp_path, '## backlog\n- 0003-alpha\n')
      git('add', '-A')
      git('commit', '-q', '-m', 'seed')

      local ok = metaplan.rename_plan(gitrepo, '0003-alpha', '0003-beta')
      assert.is_true(ok)
      local mp = utils.read_file(mp_path)
      assert.truthy(mp:find('- 0003-beta', 1, true))
      assert.is_nil(mp:find('0003-alpha', 1, true))
    end)
  end)

  describe('delete_plan', function()
    local gitrepo = '/tmp/shooter_metaplan_delete_test'
    local mp_path = gitrepo .. '/docs/plans/metaplan.md'
    local shotfiles_plans = gitrepo .. '/docs/plans'

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

    it('deletes folder + shotfile + metaplan entry and commits', function()
      vim.fn.mkdir(gitrepo .. '/docs/plans/0005-goner', 'p')
      utils.write_file(gitrepo .. '/docs/plans/0005-goner/plan.md',
        '# 0005-goner\n\nbody\n')
      utils.write_file(gitrepo .. '/docs/plans/0005-goner/idea.md',
        '# docs/plans/0005-goner/idea\n\nsome notes\n')
      utils.write_file(mp_path, table.concat({
        '## in progress',
        '- 0005-goner (desc)',
        '  - a note',
        '',
      }, '\n'))
      git('add', '-A')
      git('commit', '-q', '-m', 'seed')

      -- Plan has plan.md + idea.md → fails the "only idea.md" content
      -- rule. Force-delete bypasses the three pre-flight tiers.
      local ok, msg = metaplan.delete_plan(gitrepo, '0005-goner',
        { folder = true, force = true })
      assert.is_true(ok, msg)
      assert.is_false(utils.dir_exists(gitrepo .. '/docs/plans/0005-goner'))
      local mp = utils.read_file(mp_path)
      assert.is_nil(mp:find('0005-goner', 1, true))
      local subject = git('log', '-1', '--format=%s')
      assert.truthy(subject:find('chore%(plans%): delete 0005%-goner'))
    end)

    it('refuses delete when plan has files beyond idea.md (no force)', function()
      vim.fn.mkdir(gitrepo .. '/docs/plans/0005-blocked', 'p')
      utils.write_file(gitrepo .. '/docs/plans/0005-blocked/plan.md',
        '# 0005-blocked\n\nbody\n')
      utils.write_file(mp_path, '## in progress\n- 0005-blocked\n')
      git('add', '-A'); git('commit', '-q', '-m', 'seed')

      local ok, err = metaplan.delete_plan(gitrepo, '0005-blocked',
        { folder = true })
      assert.is_false(ok)
      assert.truthy(err:find('plan.md', 1, true))
      -- Folder still there
      assert.is_true(utils.dir_exists(gitrepo .. '/docs/plans/0005-blocked'))
    end)

    it('plan_deletable: only idea.md (or empty) → ok', function()
      vim.fn.mkdir(gitrepo .. '/docs/plans/0001-only-idea', 'p')
      utils.write_file(gitrepo .. '/docs/plans/0001-only-idea/idea.md',
        '# x\n')
      assert.is_true(metaplan.plan_deletable(gitrepo, '0001-only-idea'))
      vim.fn.mkdir(gitrepo .. '/docs/plans/0002-empty', 'p')
      assert.is_true(metaplan.plan_deletable(gitrepo, '0002-empty'))
      vim.fn.mkdir(gitrepo .. '/docs/plans/0003-with-spec', 'p')
      utils.write_file(gitrepo .. '/docs/plans/0003-with-spec/spec.md',
        '# spec\n')
      local ok, reason = metaplan.plan_deletable(gitrepo, '0003-with-spec')
      assert.is_false(ok)
      assert.truthy(reason:find('spec.md', 1, true))
    end)

    it('keeps metaplan entry when folder stays (folder=false)', function()
      vim.fn.mkdir(gitrepo .. '/docs/plans/0002-keep-folder', 'p')
      utils.write_file(gitrepo .. '/docs/plans/0002-keep-folder/plan.md',
        '# 0002-keep-folder\n\nvaluable body\n')
      utils.write_file(mp_path, table.concat({
        '## in progress',
        '- 0002-keep-folder',
        '',
      }, '\n'))
      git('add', '-A')
      git('commit', '-q', '-m', 'seed')

      local ok = metaplan.delete_plan(gitrepo, '0002-keep-folder',
        { folder = false })
      assert.is_true(ok)
      -- Folder untouched
      assert.is_true(utils.dir_exists(gitrepo .. '/docs/plans/0002-keep-folder'))
      -- Metaplan entry remains because the folder is still present.
      local mp = utils.read_file(mp_path)
      assert.truthy(mp:find('- 0002-keep-folder', 1, true))
    end)

    it('no-op on disk but still commits metaplan edit when nothing to delete', function()
      -- Plan is only referenced in metaplan; no folder.
      utils.write_file(mp_path, '## in progress\n- 0007-phantom\n')
      git('add', '-A')
      git('commit', '-q', '-m', 'seed')

      local ok = metaplan.delete_plan(gitrepo, '0007-phantom',
        { folder = true })
      assert.is_true(ok)
      local mp = utils.read_file(mp_path)
      assert.is_nil(mp:find('0007-phantom', 1, true))
    end)
  end)
end)
