-- AST → markdown: render parsed metaplan content back to canonical form,
-- with `## next plans` gap-fill renumbering.

local util = require('shooter.plans.metaplan.util')
local parse = require('shooter.plans.metaplan.parse')

local M = {}

local function render_entry(entry, out)
  table.insert(out, '- ' .. entry.text)
  for _, child in ipairs(entry.children or {}) do
    table.insert(out, child)
  end
end

-- Render parsed + title back to canonical metaplan content.
-- `## next plans` entries are renumbered using gap-fill: each entry gets the
-- smallest N >= 1 not in `opts.used_numbers` and not yet assigned in this
-- pass. When `used_numbers` is omitted, falls back to sequential renumbering
-- from the first entry's NNNN- prefix (or 1).
function M.render(parsed, title, opts)
  opts = opts or {}
  local sections = parsed.sections

  local next_plans = sections['next plans'] or {}
  if #next_plans > 0 then
    local function rewrite(entry, n)
      local stripped = parse.strip_prefix(entry.text)
      local name, rest = parse.split_at_parens(stripped)
      local slug = parse.slugify(name)
      if slug == '' then slug = 'plan' end
      if rest ~= '' then
        entry.text = string.format('%04d-%s %s', n, slug, rest)
      else
        entry.text = string.format('%04d-%s', n, slug)
      end
    end

    if opts.used_numbers then
      local used = {}
      for k, v in pairs(opts.used_numbers) do used[k] = v end
      if opts.is_locked then
        for _, entry in ipairs(next_plans) do
          if opts.is_locked(entry) then
            local n = tonumber(entry.text:match('^(%d%d%d%d)%-'))
            if n then used[n] = true end
          end
        end
      end
      local cursor = 0
      for _, entry in ipairs(next_plans) do
        if opts.is_locked and opts.is_locked(entry) then
          local n = tonumber(entry.text:match('^(%d%d%d%d)%-'))
          if n then rewrite(entry, n) end
        else
          repeat cursor = cursor + 1 until not used[cursor]
          used[cursor] = true
          rewrite(entry, cursor)
        end
      end
    else
      local start = tonumber(next_plans[1].text:match('^(%d%d%d%d)%-')) or 1
      for i, entry in ipairs(next_plans) do
        rewrite(entry, start + i - 1)
      end
    end
  end

  local out = { title, '' }
  for _, name in ipairs(util.SECTIONS) do
    table.insert(out, '## ' .. name)
    for _, entry in ipairs(sections[name] or {}) do
      render_entry(entry, out)
    end
    table.insert(out, '')
  end
  for _, name in ipairs(parsed.order) do
    if not util.is_canonical(name) then
      table.insert(out, '## ' .. name)
      for _, entry in ipairs(sections[name] or {}) do
        render_entry(entry, out)
      end
      table.insert(out, '')
    end
  end

  while #out > 0 and out[#out] == '' do table.remove(out) end
  return table.concat(out, '\n') .. '\n'
end

return M
