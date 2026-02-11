# Codebase Concerns

**Analysis Date:** 2026-02-08

## Code Quality

### Shell Injection Risk in Path String Concatenation

**Severity:** HIGH
**Category:** security

- Issue: Multiple locations use unquoted path variables in shell commands via `io.popen()` and string concatenation. While most paths are from config/git sources, user-supplied paths through Oil integration could be exploited.
- Files:
  - `lua/shooter/inbox/init.lua:33` (find command with `expanded_dir`)
  - `lua/shooter/core/repos.lua` (ls command)
  - `lua/shooter/telescope/helpers.lua` (find/ls commands)
  - `lua/shooter/analytics/data.lua:206` (find command)
  - `lua/shooter/core/project.lua` (ls -1 command)
  - `lua/shooter/health.lua:165` (find command with wc)
- Impact: If user configures inbox paths, repo paths, or project paths with special characters or shell metacharacters, injection is possible
- Fix approach: Use `vim.fn.shellescape()` consistently on all user-controlled path variables before string concatenation into shell commands. Already done in `lua/shooter/tools/token_counter.lua:31` as a pattern to follow.

### Unchecked Shell Command Failures

**Severity:** MEDIUM
**Category:** fragile

- Issue: Many shell commands via `io.popen()` redirect stderr to `/dev/null` silently (`2>/dev/null`). Failures are never checked or reported to user.
- Files:
  - `lua/shooter/utils.lua:209` (grep for shooter)
  - `lua/shooter/health.lua:162` (claude process check uses grep)
  - `lua/shooter/tmux/send.lua:57` (tmux command failure only checked via job_id)
  - `lua/shooter/health.lua:143` (git count check)
- Impact: Users may not know when critical operations fail (e.g., finding git root, detecting processes). Debugging is difficult.
- Fix approach: Capture and check exit status via `vim.v.shell_error` after `systemlist()` calls, or return error tuple from functions using `io.popen()`. Log via `vim.health.warn()` where appropriate.

### Missing Error Handling in File Operations

**Severity:** MEDIUM
**Category:** fragile

- Issue: File read/write operations check `if not file` but assume all other operations succeed. No error messages returned to caller on failures.
- Files:
  - `lua/shooter/utils.lua:133-140` (io.popen might fail silently)
  - `lua/shooter/analytics/data.lua:34-37` (file:read() on opened file)
  - `lua/shooter/health/tools.lua` (plugin detection might silently fail)
- Impact: If filesystem is read-only, disk full, or permissions denied, users get no feedback. State may be partially written.
- Fix approach: Return error tuples from all I/O functions. Propagate errors up to command handlers which call `vim.notify()` with the error.

### Fragile Time-Based Lookups in Response Viewer

**Severity:** MEDIUM
**Category:** fragile

- Issue: Response viewer uses timestamp parsing from shot headers to find temp files. Old shots without `@ref` fall back to parsing header timestamps with regex, converting to file format. Edge cases around date formatting could cause mismatches.
- Files: `lua/shooter/tools/response_viewer.lua:12-20`
- Impact: Users may get "no response found" for shots that do have responses if timestamp format slightly changes or parsing logic has edge cases (timezone, formatting variations).
- Fix approach: Always generate and store `@ref` in shot headers on creation. Deprecate timestamp-based fallback after transition period. Add tests for timestamp parsing edge cases.

## Architecture

### Tight Coupling Between Tmux and Vim Operations

**Severity:** MEDIUM
**Category:** tech-debt

- Issue: Tmux operations are deeply integrated throughout the plugin. Oil file browser, shot sending, pane navigation, and response fetching all depend on tmux being available, but error messages are inconsistent.
- Files:
  - `lua/shooter/core/shot_actions.lua` (shot operations assume tmux)
  - `lua/shooter/tmux/wrapper.lua` (bare script paths without full resolution)
  - `lua/shooter/tmux/send.lua:56-67` (async job handling with weak error semantics)
- Impact: Plugin is not usable without tmux, but this isn't clearly enforced. Partial failures in tmux commands are silently ignored.
- Fix approach: Create a tmux abstraction layer that fails fast with clear error messages. Add guards at entry points (`ShoShotCreate`, etc.) to check tmux availability before attempting operations.

### Complex Regex Patterns for Shot Headers

**Severity:** LOW
**Category:** fragile

- Issue: Shot header patterns are duplicated as hardcoded regex strings across multiple files instead of centralized in config.
- Files:
  - `lua/shooter/core/shots.lua` (parsing shot headers)
  - `lua/shooter/analytics/data.lua:45,55` (pattern matching)
  - `lua/shooter/config.lua:87-93` (defined but may not be used everywhere)
- Impact: If shot header format changes, multiple files must be updated in sync. Risk of inconsistency.
- Fix approach: Use `config.get('patterns.shot_header')` everywhere. Add unit tests for pattern changes.

## Dependencies

### Required Plugin: vim-i3wm-tmux-navigator

**Severity:** MEDIUM
**Category:** dependency

- Issue: Plugin is marked as required in `lua/shooter/health.lua:36-48` but vim-i3wm-tmux-navigator repo (fogine) is not widely maintained. Name suggests i3 window manager dependency which limits cross-platform use.
- Files: `lua/shooter/health.lua:36-49`
- Impact: Plugin may break on new Vim/Neovim versions if navigator plugin is abandoned. Users on non-i3 systems still required to install it.
- Fix approach: Make navigator optional. Detect its presence and conditionally enable pane navigation features. Provide fallback implementations for non-navigator systems.

### External Script Paths Not Validated

**Severity:** MEDIUM
**Category:** fragile

- Issue: `lua/shooter/tmux/wrapper.lua` runs scripts by name (e.g., `d-tmux-edit-vim`, `d-tmux-lightswitch`) without validating they exist or are executable. Hardcoded absolute paths (e.g., `~/dev/scripts`).
- Files: `lua/shooter/tmux/wrapper.lua:48, 57, 67, 79`
- Impact: If scripts are missing or moved, users get vague "command not found" errors. Hardcoded paths break for users with different dev directory layouts.
- Fix approach: Make script paths configurable. Validate script existence at startup via health checks. Return clear errors if scripts missing.

## Testing

### Untested Critical Paths

**Severity:** MEDIUM
**Category:** test-gap

- Issue: 33 test files exist but key functionality is untested:
  - No tests for shell command injection prevention
  - No tests for response viewer file lookup logic with edge cases
  - No tests for tmux send-keys with special characters
  - No tests for config merging with user overrides
  - No tests for analytics data parsing with malformed shot headers
- Files: All `lua/shooter/*` modules lack comprehensive test coverage
- Impact: Regressions in critical paths (file operations, shell execution) go undetected until user reports.
- Fix approach: Add tests for:
  1. Shell injection scenarios (paths with spaces, quotes, semicolons)
  2. Response viewer timestamp parsing edge cases
  3. Config override scenarios
  4. Analytics parsing with malformed data

### Test Infrastructure Issues

**Severity:** LOW
**Category:** test-gap

- Issue: `tests/minimal_init.lua:15` runs `vim.fn.system()` directly which can cause terminal bleed. Pattern conflicts with the philosophy of `lua/shooter/tmux/send.lua:55-67` which uses `jobstart()` instead.
- Files: `tests/minimal_init.lua`
- Impact: Test output may corrupt terminal state.
- Fix approach: Use `jobstart()` + `jobwait()` pattern consistently in tests as well.

## Performance

### Unbounded Directory Traversal in Analytics

**Severity:** LOW
**Category:** performance

- Issue: `lua/shooter/analytics/data.lua:206` uses `find` command without depth limits or size exclusions. Large project trees or symlinks could cause slow scans.
- Files: `lua/shooter/analytics/data.lua:186, 206`
- Impact: Dashboard or analytics commands may hang on large repos with deep nesting.
- Fix approach: Add `find ... -maxdepth` limits and exclude common large dirs (`node_modules`, `.git`, `.venv`).

## Security

### User File Access via Oil Integration

**Severity:** LOW
**Category:** security

- Issue: `lua/shooter/core/files.lua:40-57` integrates with Oil plugin. If Oil allows selecting files outside shooter directories, those paths are passed to file operations.
- Files: `lua/shooter/core/files.lua:40-57`, `lua/shooter/core/movement.lua:72-100`
- Impact: Users could accidentally move/delete arbitrary files if Oil is not properly scoped. Requires coordinated Oil misconfiguration.
- Fix approach: Validate that file operations only touch `.shooter/ai/shotfiles` subdirectories. Add warning if user attempts to operate on files outside expected paths.

### Obsidian URL Formation Not Fully Escaped

**Severity:** LOW
**Category:** security

- Issue: `lua/shooter/tools/obsidian.lua:89` uses `string.format('%s "%s"', open_cmd, url)` where `open_cmd` is hardcoded but URL could have edge cases. URL escaping via `url_encode()` may not cover all obsidian:// URI edge cases.
- Files: `lua/shooter/tools/obsidian.lua:72-90`
- Impact: Malformed Obsidian URLs if file paths contain unusual Unicode or encoding edge cases. Low likelihood in practice.
- Fix approach: Use Vim's built-in URI encoding if available, or validate URL format matches obsidian:// spec.

### Debug Info Leakage

**Severity:** LOW
**Category:** security

- Issue: `lua/shooter/tools/clipboard_image.lua` uses `debug.getinfo()` to detect caller location. Debug info could theoretically leak internal paths in error messages.
- Files: `lua/shooter/tools/clipboard_image.lua`
- Impact: Minimal in practice, but paths in error messages could reveal system layout.
- Fix approach: Sanitize error messages to remove full paths; use relative or shortened paths only.

## Known Limitations

### Neovim Version Compatibility

**Severity:** LOW
**Category:** missing-feature

- Issue: No `nvim_version` checks in codebase. Uses modern Lua APIs (e.g., `vim.notify`, `vim.ui.input`) without version guards.
- Files: `lua/shooter/init.lua`, `lua/shooter/config.lua`
- Impact: Plugin may fail on older Neovim versions (< 0.7) where these APIs don't exist.
- Fix approach: Add version check in `setup()`. Provide graceful degradation or clear error message for unsupported versions.

---

*Concerns audit: 2026-02-08*
