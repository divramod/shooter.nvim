-- Collect, classify, and open link-like tokens from text.
-- Used by HalShooterOpenLinkPicker and HalShooterOpenLinkPickerTmux.
local M = {}

local md_links = require('shooter.markdown_links')

-- File extensions we prefer to hand off to the system opener (images,
-- documents, audio, video) rather than editing in nvim.
local BINARY_EXTS = {
  png = true, jpg = true, jpeg = true, gif = true, webp = true, svg = true,
  bmp = true, tiff = true, heic = true,
  pdf = true, epub = true, mobi = true,
  mp3 = true, wav = true, flac = true, ogg = true, m4a = true,
  mp4 = true, mov = true, mkv = true, avi = true, webm = true,
  zip = true, tar = true, gz = true, bz2 = true, ['7z'] = true,
}

-- Expand ~ / $HOME in a path.
local function expand(path)
  if not path then return nil end
  if path:sub(1, 1) == '~' then
    local home = os.getenv('HOME') or ''
    path = home .. path:sub(2)
  end
  return path
end

-- Extract the target of a raw link token. For `[text](url)` that's the URL
-- between the parens; for a plain path/URL it's the token itself.
function M.extract_target(raw)
  if not raw then return nil end
  local url = raw:match('^%b[]%((.-)%)%s*$')
  if url then return url end
  -- Angle-bracketed URL: <http://foo>
  local angled = raw:match('^<(.-)>$')
  if angled then return angled end
  return raw
end

-- Classify a target string as 'web' | 'file' | 'dir' | 'other'. The 'other'
-- bucket covers strings we can't reason about (e.g. non-existent paths).
function M.classify(target)
  if not target or target == '' then return 'other' end
  if target:match('^https?://') or target:match('^%a[%w+.%-]*://') then
    return 'web'
  end
  local path = expand(target)
  if not path then return 'other' end
  if vim.fn.isdirectory(path) == 1 then return 'dir' end
  if vim.fn.filereadable(path) == 1 then return 'file' end
  -- Best-effort: if the raw string ends with a path separator treat as dir.
  if target:sub(-1) == '/' then return 'dir' end
  return 'other'
end

-- Collect link entries from an array of lines. Each entry:
--   { line, col, raw, target, kind, source, display }
-- line/col are 1-based buffer positions (col is 0-based byte offset for
-- extmark compat). `source` is an optional label (e.g. pane title).
function M.collect_from_lines(lines, source)
  local out = {}
  for lnum, line in ipairs(lines) do
    for _, range in ipairs(md_links.find_ranges(line)) do
      local raw = line:sub(range[1] + 1, range[2])
      local target = M.extract_target(raw)
      local kind = M.classify(target)
      table.insert(out, {
        line = lnum,
        col = range[1],
        raw = raw,
        target = target,
        kind = kind,
        source = source,
      })
    end
  end
  return out
end

-- Call the OS "open" command for a URL or path. Prefers vim.ui.open (0.10+).
function M.system_open(target)
  if vim.ui and vim.ui.open then
    vim.ui.open(target)
    return true
  end
  local cmd
  if vim.fn.has('mac') == 1 then
    cmd = 'open'
  elseif vim.fn.has('unix') == 1 then
    cmd = 'xdg-open'
  else
    return false
  end
  vim.fn.jobstart({ cmd, target }, { detach = true })
  return true
end

-- Dispatch: open a classified link using the right mechanism.
function M.open(entry)
  if not entry or not entry.target then return end
  local target = entry.target
  local kind = entry.kind or M.classify(target)

  if kind == 'web' then
    M.system_open(target)
    return
  end

  if kind == 'dir' then
    local path = expand(target)
    local ok, _ = pcall(function()
      vim.cmd('edit ' .. vim.fn.fnameescape(path))
    end)
    if not ok then M.system_open(path) end
    return
  end

  if kind == 'file' then
    local path = expand(target)
    local ext = (path:match('%.([%w]+)$') or ''):lower()
    if BINARY_EXTS[ext] then
      M.system_open(path)
    else
      vim.cmd('edit ' .. vim.fn.fnameescape(path))
    end
    return
  end

  -- Unknown / non-existent: hand off to the system opener as a last resort.
  M.system_open(target)
end

return M
