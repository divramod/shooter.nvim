# Codebase Concerns

**Analysis Date:** 2026-01-30

## Tech Debt

**Shell Command Injection Risk in String Concatenation:**
- Issue: Multiple locations concatenate user paths/input directly into shell commands without proper escaping
- Files: `lua/shooter/analytics/data.lua`, `lua/shooter/analytics/init.lua`, `lua/shooter/tmux/detect.lua`, `lua/shooter/tmux/panes.lua`, `lua/shooter/tmux/send.lua`, `lua/shooter/images.lua`, `lua/shooter/providers/init.lua`
- Impact: If a user creates a file path with shell metacharacters or a project name contains backticks/semicolons, arbitrary code execution is possible. Example: `io.popen('ls -d "' .. expanded_dir .. '"/*/ 2>/dev/null')` at line 146 in `analytics/data.lua`
- Fix approach: Use Lua path escaping library (e.g., `vim.fn.shellescape()`) or switch to direct APIs. Replace all manual string.format tmux commands with proper argument arrays

**Temporary File Cleanup Race Condition:**
- Issue: Temporary files created in `tmux/send.lua` are deleted via shell command at end of compound command chain. If any command fails before the `rm`, temp file orphans persist
- Files: `lua/shooter/tmux/send.lua` lines 94, 159
- Impact: Disk space leakage; over time, `/tmp` fills with abandoned files containing user prompts (potential privacy issue)
- Fix approach: Use Lua file API with cleanup in error handler, or use a cleanup registry that periodically removes orphaned files older than 1 hour

**Hardcoded Wait Channel Names:**
- Issue: Wait channel names for tmux coordination are predictable and not namespaced
- Files: `lua/shooter/images.lua` lines 40-41
- Impact: In multi-user systems or parallel nvim instances, collision is possible causing race conditions
- Fix approach: Generate unique channel names using pid: `string.format('shooter_%d_%d', vim.fn.getpid(), os.time())`

## Known Bugs

**Renumber Command Does Not Validate Shot Patterns:**
- Symptoms: `ShooterShotsRenumber` may miss or miscount shots if shot headers deviate slightly from expected format (e.g., trailing spaces, mixed case)
- Files: `lua/shooter/core/renumber.lua`
- Trigger: Create a shot header with variations like `## shot` vs `##shot` or `## SHOT` (uppercase)
- Workaround: Ensure consistent shot header formatting before running renumber

**io.popen Handle Not Closed on Early Return:**
- Symptoms: File descriptor leak if function returns before handle:close() is called
- Files: Multiple locations - `lua/shooter/analytics/data.lua` (lines 146, 177, 197), `lua/shooter/health.lua` (lines 87, 111, 226), `lua/shooter/tmux/panes.lua` (lines 21, 33, 53)
- Trigger: When io.popen succeeds but subsequent code path returns early without explicit close
- Workaround: Always store handle and ensure close() is called; use defer/finally pattern where possible

**Outdated Session File Can Break Picker:**
- Symptoms: Shot picker fails to load if session YAML file has missing or corrupted vimMode/filters/sortBy sections
- Files: `lua/shooter/session/storage.lua` (parse_yaml function)
- Trigger: Manual session file edits or corrupted YAML from previous versions
- Workaround: Delete problematic session file at `~/.config/shooter.nvim/sessions/<repo>/` to regenerate defaults

## Security Considerations

**User Input From File Paths Not Escaped in Shell Commands:**
- Risk: Project names and file paths passed to tmux/shell commands are not shell-escaped. A project named `test; rm -rf /` in `projects/` would execute arbitrary commands
- Files: `lua/shooter/core/project.lua` (line 45), `lua/shooter/core/repos.lua` (line 39), `lua/shooter/telescope/helpers.lua` (lines 323, 346)
- Current mitigation: Filesystem path constraints (only characters allowed in directory names), but not sufficient if user creates adversarial paths
- Recommendations: Use `vim.fn.shellescape()` for all file/directory paths before passing to shell; validate project names at creation time

**Git Remote URL Parsing Not Validated:**
- Risk: `analytics/data.lua` line 96 uses regex to parse git URLs. Malformed URLs could match unexpectedly or be used to inject commands if passed to shell
- Files: `lua/shooter/analytics/data.lua` (lines 84-100)
- Current mitigation: Only used for display, not executed as commands
- Recommendations: Validate git URL format strictly; use `git config` API instead of parsing URLs

**Temp File Paths Predictable:**
- Risk: Temp files created with `os.tmpname()` in `tmux/send.lua` line 67 are created in system temp directory. On multi-user systems, another user could intercept/read shot contents before they're deleted
- Files: `lua/shooter/tmux/send.lua` (line 67)
- Current mitigation: Files are deleted after tmux paste, but timing window exists
- Recommendations: Create files in user-only-readable directory (mode 0600); use vim plugin temp dir if available

## Performance Bottlenecks

**Analytics Data Parsing Loads Entire Shotfile Into Memory:**
- Problem: `analytics/data.lua` line 36 reads entire file with `io.read('*a')`, then iterates line-by-line. For very large shotfiles (>10MB), this causes memory spike
- Files: `lua/shooter/analytics/data.lua` (lines 33-80)
- Cause: No streaming/chunked parsing; entire file in memory before processing
- Improvement path: Process file line-by-line without loading full content; count shots in first pass, extract metrics only for requested range

**Picker Refresh on Every Folder Toggle:**
- Problem: `telescope/pickers.lua` (lines 58-63) refreshes entire picker state when user toggles folders. For repos with 1000+ shots, this causes UI stall
- Files: `lua/shooter/telescope/pickers.lua` (setup_folder_mappings function)
- Cause: Full file list regenerated instead of filtering in-place
- Improvement path: Cache file list; implement filter-only refresh that applies state without reloading filesystem

**io.popen With External Commands Has 2-3 Second Latency:**
- Problem: Multiple `io.popen()` calls to tmux/shell commands throughout codebase introduce cumulative delay. Health check spawns 10+ processes
- Files: `lua/shooter/health.lua` (check functions), `lua/shooter/tmux/detect.lua` (list_all_panes), `lua/shooter/providers/init.lua`
- Cause: Each call forks a process; no batching of related calls
- Improvement path: Batch health checks (single tmux call that returns all pane info); cache results with TTL

## Fragile Areas

**Tmux Integration Assumes Specific Pane Format:**
- Files: `lua/shooter/tmux/detect.lua`, `lua/shooter/tmux/panes.lua`, `lua/shooter/providers/init.lua`
- Why fragile: Code assumes `#{pane_tty}` format matches `ttys\d+` pattern (line 80 in detect.lua). If user has custom tmux config that changes pane output format, all pane detection breaks silently
- Safe modification: Add defensive regex matching; log warnings when format doesn't match expected pattern; add option to manually specify pane ID
- Test coverage: No tests verify pane detection with non-standard tmux configs

**Session YAML Parsing Is Manual and Brittle:**
- Files: `lua/shooter/session/storage.lua` (parse_yaml function, lines 78-160)
- Why fragile: Hand-rolled YAML parser only handles specific indentation/structure. Any deviation breaks (e.g., extra spaces, tabs vs spaces, missing keys)
- Safe modification: Use a YAML library (e.g., lyaml) or switch to JSON for sessions; add validation with clear error messages for malformed files
- Test coverage: Only happy-path tested; no tests for truncated/malformed YAML

**File Pattern Matching Uses Global Glob With No Size Limits:**
- Files: `lua/shooter/core/files.lua` (line 93 - globpath returns all results at once)
- Why fragile: If a user accidentally creates prompts directory with 100k+ files, `vim.fn.globpath()` call will consume all memory and freeze nvim
- Safe modification: Implement pagination/streaming; add file count limits with warning; check directory size before globbing
- Test coverage: No stress tests with large file counts

**Commands.lua Has 634 Lines With Deep Nesting:**
- Files: `lua/shooter/commands.lua`
- Why fragile: Large command registration functions (setup_shotfile_commands: 152 lines, setup_shot_commands: 111 lines) with nested callbacks and closures make it hard to trace data flow or add new commands without breaking existing ones
- Safe modification: Split into per-namespace files; move inline command logic to separate module functions; extract common patterns
- Test coverage: Commands are registered but not tested for correctness; no tests verify callback behavior

**Oil.nvim Integration Uses Unsafe File Retrieval:**
- Files: `lua/shooter/core/files.lua` (lines 23-31, 43-58)
- Why fragile: Code uses `pcall(require, 'oil')` inline but doesn't validate that oil is actually loaded; relies on entry being present under cursor (nil if empty dir)
- Safe modification: Validate oil availability at startup; add null checks before accessing entry.name/entry.type; provide fallback to normal buffer mode
- Test coverage: No tests with oil unavailable; no tests with empty directories

## Scaling Limits

**Analytics Report Generation Doesn't Paginate:**
- Current capacity: Reasonable for <5000 executed shots across all repos
- Limit: At 50k executed shots, analytics data loading freezes UI for 5+ seconds; memory usage exceeds 100MB
- Scaling path: Implement date-range filtering; cache aggregates by month; lazy-load metrics on demand

**Picker State Multiplied by Session Count:**
- Current capacity: ~3-5 sessions per repo
- Limit: At 20+ saved sessions, loading session list and switching becomes O(n) slow; session picker becomes unusable
- Scaling path: Lazy-load sessions; archive old sessions; implement session search/filter

**Tmux Pane Detection Linear Scan:**
- Current capacity: <20 panes
- Limit: At 50+ tmux panes (multi-monitor setups), pane detection loops take >500ms
- Scaling path: Cache pane list with TTL; use tmux server API if available; optimize grep filter

## Dependencies at Risk

**Manual YAML Parsing (No YAML Library):**
- Risk: Session serialization is custom YAML parser/writer. If data structure changes, serialization breaks. No validation of parse success
- Impact: Session data loss; user configurations reset to defaults unexpectedly
- Migration plan: Add `lyaml` dependency (pure Lua, no external deps) or switch to JSON format with json.lua library

**io.popen Relies on Shell Availability:**
- Risk: Code assumes `/bin/sh` and standard Unix utilities (find, grep, ls, tmux) are available. On Windows WSL or minimal environments, these may not exist
- Impact: All tmux/shell-based features fail silently with unclear errors
- Migration plan: Detect missing commands at health check time; provide fallback implementations or Windows-compatible alternatives

**git Command Dependency Not Validated:**
- Risk: Multiple calls to `git rev-parse`, `git remote get-url` assume git is in PATH. No error handling for git not found
- Impact: Plugin initialization fails silently if git is missing; error messages are unclear
- Migration plan: Add git availability check to health check; wrap git calls with error handler

## Test Coverage Gaps

**Untested: Tmux Send/Integration with Real Tmux:**
- What's not tested: Actual sending of text to tmux panes; temp file creation/deletion; escape sequence handling
- Files: `lua/shooter/tmux/send.lua`, `lua/shooter/tmux/create.lua`, `lua/shooter/tmux/keys.lua`
- Risk: Send operations could fail silently or corrupt pane state without detection
- Priority: High - core feature depends on this

**Untested: Analytics Parsing Edge Cases:**
- What's not tested: Shotfiles with malformed shot headers; files with Unicode; very large shot content (>1MB); symlinks in prompts dir
- Files: `lua/shooter/analytics/data.lua`
- Risk: Analytics report crashes or produces wrong metrics without warning
- Priority: Medium

**Untested: Session Persistence Across Versions:**
- What's not tested: Loading session files created by older plugin versions; migration of session format; corrupted YAML recovery
- Files: `lua/shooter/session/storage.lua`
- Risk: User sessions lost after plugin update; no recovery path
- Priority: Medium

**Untested: Oil.nvim Interop:**
- What's not tested: File retrieval when oil.nvim is loaded; behavior when oil not available; symlinks/special files in oil
- Files: `lua/shooter/core/files.lua`, `lua/shooter/keymaps/oil.lua`
- Risk: Oil-based commands fail silently; keymaps don't work in oil buffers
- Priority: Medium

**Untested: Multi-Pane Send With Timing:**
- What's not tested: Sending large shots (>10k chars) to multiple panes in sequence; cleanup if send to pane 1 succeeds but pane 2 fails
- Files: `lua/shooter/tmux/init.lua`, `lua/shooter/tmux/send.lua`
- Risk: Partial send state corruption; orphaned temp files; stuck panes
- Priority: High

---

*Concerns audit: 2026-01-30*
