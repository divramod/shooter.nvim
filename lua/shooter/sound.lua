-- Sound playback for shooter.nvim
-- Play notification sounds when shots are sent

local config = require('shooter.config')
local utils = require('shooter.utils')

local M = {}

-- Expand path (handle ~ for home directory)
local function expand_path(path)
  if path:sub(1, 1) == '~' then
    return vim.fn.expand(path)
  end
  return path
end

-- Check if sound file exists
local function sound_file_exists(filepath)
  local expanded = expand_path(filepath)
  return vim.fn.filereadable(expanded) == 1
end

-- Play sound using afplay (macOS) or paplay (Linux)
-- Runs asynchronously so it doesn't block
function M.play()
  -- Check if sound is enabled
  if not config.get('sound.enabled') then
    return
  end

  local sound_file = config.get('sound.file')
  if not sound_file or sound_file == '' then
    return
  end

  local expanded_path = expand_path(sound_file)

  -- Check if file exists
  if not sound_file_exists(sound_file) then
    -- Silently fail - don't spam errors for missing sound
    return
  end

  local volume = config.get('sound.volume') or 0.5
  -- Clamp volume between 0 and 1
  volume = math.max(0, math.min(1, volume))

  -- Detect platform and build command
  local cmd
  if vim.fn.has('mac') == 1 then
    -- macOS: use afplay with volume flag
    -- afplay volume is 0-255 for some versions, 0-1 for others
    -- Using the simpler approach with -v flag (volume multiplier)
    cmd = string.format('afplay -v %.2f "%s" &', volume, expanded_path)
  elseif vim.fn.has('unix') == 1 then
    -- Linux: try paplay (PulseAudio) with volume
    -- paplay volume is in percentage (0-65536, 100% = 65536)
    local pa_volume = math.floor(volume * 65536)
    cmd = string.format('paplay --volume=%d "%s" &', pa_volume, expanded_path)
  else
    -- Unsupported platform
    return
  end

  -- Run asynchronously using vim.fn.jobstart
  vim.fn.jobstart(cmd, {
    detach = true,
    on_stderr = function() end, -- Ignore errors
  })
end

-- Play sound with custom file (one-off)
function M.play_file(filepath, volume)
  if not filepath or filepath == '' then
    return
  end

  local expanded_path = expand_path(filepath)
  if vim.fn.filereadable(expanded_path) ~= 1 then
    return
  end

  volume = volume or 0.5
  volume = math.max(0, math.min(1, volume))

  local cmd
  if vim.fn.has('mac') == 1 then
    cmd = string.format('afplay -v %.2f "%s" &', volume, expanded_path)
  elseif vim.fn.has('unix') == 1 then
    local pa_volume = math.floor(volume * 65536)
    cmd = string.format('paplay --volume=%d "%s" &', pa_volume, expanded_path)
  else
    return
  end

  vim.fn.jobstart(cmd, {
    detach = true,
    on_stderr = function() end,
  })
end

-- Test sound (for health check or manual testing)
function M.test()
  local sound_enabled = config.get('sound.enabled')
  local sound_file = config.get('sound.file')
  local volume = config.get('sound.volume') or 0.5

  if not sound_enabled then
    utils.echo('Sound is disabled. Enable with sound.enabled = true')
    return
  end

  if not sound_file or sound_file == '' then
    utils.echo('No sound file configured')
    return
  end

  local expanded = expand_path(sound_file)
  if not sound_file_exists(sound_file) then
    utils.echo('Sound file not found: ' .. expanded)
    return
  end

  M.play()
  utils.echo('Playing: ' .. expanded .. ' (volume: ' .. volume .. ')')
end

return M
