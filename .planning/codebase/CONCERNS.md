# Codebase Concerns

**Analysis Date:** 2026-04-03

## Tech Debt

**Largest file: `lua/shooter/core/shot_actions.lua` (812 lines):**
- Issue: This file contains 15+ functions spanning shot creation, deletion, navigation, yanking, extraction, stats, and Claude integration. Several functions share duplicated logic (e.g., `create_new_shot` and `create_new_shot_with_whisper` are nearly identical except for the whisper tail).
- Files: `lua/shooter/core/shot_actions.lua`
- Impact: Hard to modify shot creation behavior without touching multiple places. Risk of inconsistency between parallel code paths.
- Fix approach: Extract `find_insertion_line` + shot creation into a single `create_shot_skeleton(bufnr, opts)` helper. Whisper, Claude-from-file, and normal creation would all delegate to it.

**Duplicated `write_shot_creator_script` inline script:**
- Issue: `lua/shooter/core/shot_actions.lua` lines 690-756 contain a full self-contained Lua script as a string template. This duplicates logic from `find_insertion_line`, `get_next_shot_number`, and buffer manipulation that already exists in the module. The string-embedded script cannot be tested or linted.
- Files: `lua/shooter/core/shot_actions.lua`
- Impact: Any change to shot insertion logic must be replicated in the embedded string. Bugs in the embedded script are invisible to the test suite.
- Fix approach: Use `vim.rpcrequest` or a named RPC call from the tmux pane to the running nvim instance instead of generating a standalone `:luafile` script. This keeps all logic in one place.

**Hardcoded `/tmp/shooter-*` temp file paths:**
- Issue: Multiple temp file paths are hardcoded across files: `/tmp/shooter-claude-shot.md`, `/tmp/shooter-claude-shot-cmd.lua`, `/tmp/shooter-pane-*`, `/tmp/shooter-folder-*`, `/tmp/shooter_watch_layout_*`.
- Files: `lua/shooter/core/shot_actions.lua`, `lua/shooter/tmux/toggle_panes.lua`, `lua/shooter/tmux/watch.lua`
- Impact: Collisions if multiple nvim instances run simultaneously. No cleanup on crash. Not portable (assumes `/tmp` exists and is writable).
- Fix approach: Centralize temp path generation in `lua/shooter/utils.lua` using `os.tmpname()` or a PID-scoped directory like `/tmp/shooter-${PID}/`. Register cleanup with `vim.api.nvim_create_autocmd('VimLeavePre', ...)`.

**Pervasive `io.popen` usage (47 calls across 20 files):**
- Issue: `io.popen` is used extensively for shell commands throughout the codebase. This is synchronous and blocks the Neovim event loop during execution. The return value of `handle:close()` is not consistently checked for exit status.
- Files: `lua/shooter/providers/init.lua` (6 calls), `lua/shooter/tmux/panes.lua` (7 calls), `lua/shooter/analytics/data.lua` (3 calls), and 17 other files
- Impact: UI freezes during slow shell commands (e.g., `ps aux` piped through `grep`, `git rev-parse`). Potential for undetected failures when `io.popen` returns nil or the command fails.
- Fix approach: Migrate to `vim.fn.jobstart` with callbacks for non-blocking execution, or at minimum use `vim.fn.system`/`vim.fn.systemlist` which integrate better with Neovim's event loop. Already partially done in `lua/shooter/tmux/send.lua` (`execute_tmux_command` uses `vim.fn.jobstart`).

**`os.execute` used without exit code checking:**
- Issue: `os.execute` is called in 4 files. In `lua/shooter/tmux/toggle_panes.lua` and `lua/shooter/tmux/hidden_session.lua`, the result is discarded entirely (`tmux_run` ignores the return value).
- Files: `lua/shooter/tmux/toggle_panes.lua`, `lua/shooter/tmux/hidden_session.lua`, `lua/shooter/tmux/keys.lua`, `lua/shooter/tools/obsidian.lua`
- Impact: Silent failures when tmux commands fail (e.g., session doesn't exist, pane already killed). User sees no error.
- Fix approach: Check return value or migrate to `vim.fn.jobstart` for async execution with error callbacks.

**Backward compatibility aliases in `lua/shooter/tmux/create.lua`:**
- Issue: Multiple `_claude`-suffixed aliases exist alongside the generic `_ai` versions: `start_claude_in_pane`, `create_left_pane`, `is_pane_running_claude`, `wait_for_claude`, `start_and_wait_for_claude`, `find_or_create_claude_pane`.
- Files: `lua/shooter/tmux/create.lua`
- Impact: Unclear which API is canonical. New code may accidentally use the deprecated aliases.
- Fix approach: Add deprecation warnings to aliases. Remove after one release cycle.

**`commands.lua` is a 735-line registration file:**
- Issue: All command registrations live in a single file. Each command closure inlines its logic or does light delegation. There is no command metadata table, making it hard to enumerate available commands programmatically.
- Files: `lua/shooter/commands.lua`
- Impact: Adding new commands means scrolling through 700+ lines. No structured way to generate help or cheatsheets from command definitions.
- Fix approach: Extract command definitions into a declarative table `{ name, fn, opts, alias, desc }` and register them in a loop.

## Security Considerations

**`--dangerously-skip-permissions` flag hardcoded:**
- Risk: `lua/shooter/tmux/create.lua` line 21 starts Claude with `--dangerously-skip-permissions` by default when auto-creating AI panes.
- Files: `lua/shooter/tmux/create.lua`
- Current mitigation: Only triggers when user explicitly sends a shot (not on plugin load). User sees the provider selection prompt.
- Recommendations: Make the flag configurable. Default to safe mode and let users opt in via config.

**Shell command injection surface in tmux send operations:**
- Risk: Pane IDs and file paths are interpolated into shell command strings throughout the tmux module. While pane IDs come from tmux itself, file paths derived from user content (shot titles, project names) could theoretically contain shell metacharacters.
- Files: `lua/shooter/tmux/send.lua`, `lua/shooter/tmux/toggle_panes.lua`, `lua/shooter/tmux/keys.lua`
- Current mitigation: `vim.fn.shellescape` is used in some places (e.g., clipboard_image) but not consistently in tmux send paths.
- Recommendations: Audit all `string.format` calls that build shell commands. Use `vim.fn.shellescape` or pass arguments as arrays to `vim.fn.jobstart` (which avoids shell interpretation entirely).

## Performance Bottlenecks

**Provider detection calls `ps aux` per pane:**
- Problem: `detect_provider_for_pane` and `detect_provider_for_tty` each run `ps aux | grep -E ... | grep -v grep | awk` for every registered provider.
- Files: `lua/shooter/providers/init.lua`
- Cause: No caching. Each send operation triggers detection. With 5 providers, this means up to 5 `ps aux` calls per shot send.
- Improvement path: Cache detection results with a short TTL (e.g., 5 seconds). The `get_all_pane_providers()` batch-read function is already efficient; extend the caching pattern to the ps fallback.

**Synchronous `vim.wait` calls block UI:**
- Problem: `lua/shooter/tmux/create.lua` uses `vim.wait(5000, ...)` and `vim.wait(500, ...)` to wait for AI startup. `lua/shooter/tmux/operations.lua` uses `vim.wait(150, ...)` for escape sequence draining.
- Files: `lua/shooter/tmux/create.lua`, `lua/shooter/tmux/operations.lua`
- Cause: Blocking waits are used because the subsequent buffer operations need the pane to be ready.
- Improvement path: The 150ms drain waits are fine. The 5-second and 15-second AI startup waits in `start_and_wait_for_ai` could show a progress indicator or use `vim.defer_fn` with a callback chain.

## Fragile Areas

**iTerm2 OSC 1337 escape sequence workaround:**
- Files: `lua/shooter/tmux/operations.lua` lines 115-131, 169-173, 247-252
- Why fragile: When tmux creates a split pane, iTerm2 sends OSC 1337 clipboard escape sequences that arrive as typeahead in Neovim. The workaround locks the buffer, waits 150ms, drains typeahead, then unlocks. This is timing-dependent and may break with different terminal emulators or iTerm2 versions.
- Safe modification: Always keep the lock/drain pattern when modifying `send_current_shot` or `send_specific_shots`. Test with iTerm2 specifically.
- Test coverage: Not tested (requires real tmux + iTerm2).

**Shot renumbering during send:**
- Files: `lua/shooter/tmux/operations.lua`, `lua/shooter/tmux/renumber_helper.lua`
- Why fragile: After marking a shot as executed, the entire buffer is renumbered (open shots move to top, done shots to bottom). The original shot is then located by content hash. If two shots have identical content, the wrong one may be found.
- Safe modification: Always verify with the renumber test suite. Consider adding a unique shot ID instead of relying on content hashes.
- Test coverage: `tests/tmux/renumber_helper_spec.lua` covers basic cases.

**Toggle pane state tracking is in-memory only:**
- Files: `lua/shooter/tmux/toggle_panes.lua`
- Why fragile: The `state` table (line 17) maps pane names to their tmux pane IDs, hidden window names, and other metadata. This state is lost on Neovim restart. If Neovim crashes while panes are hidden, there is no way to automatically reconnect to the hidden session panes (though manual recovery via the hidden session window names is possible).
- Safe modification: The `setup_pane_for_hiding` function writes marker files to `/tmp/` as a partial workaround, but these are not read back on startup.
- Test coverage: `tests/tmux/toggle_panes_spec.lua` covers the logic with mocked tmux commands.

## Scaling Limits

**Analytics scans all shotfiles synchronously:**
- Current capacity: Works fine for dozens of shotfiles.
- Limit: `lua/shooter/analytics/data.lua` reads and parses every shotfile via `io.open`/`io.read('*a')` in a loop. For repositories with hundreds of shotfiles spanning months of history, this will cause noticeable UI pauses.
- Files: `lua/shooter/analytics/data.lua`
- Scaling path: Cache parsed shot data keyed by file mtime. Only re-parse files that changed since last scan.

## Dependencies at Risk

**Hard dependency on Telescope:**
- Risk: Telescope is required at plugin load time in multiple modules. If Telescope is not installed, those `require` calls fail.
- Files: `lua/shooter/telescope/pickers.lua`, `lua/shooter/telescope/helpers.lua`, `lua/shooter/telescope/actions.lua`, `lua/shooter/telescope/previewers.lua`, `lua/shooter/telescope/toggle_panes_picker.lua`
- Impact: Plugin cannot function without Telescope.
- Migration plan: Not urgent (Telescope is ubiquitous), but the non-picker functionality (shot management, tmux operations) could work without it if the requires were lazy.

**Hard dependency on oil.nvim:**
- Risk: `lua/shooter/keymaps/oil.lua` and `lua/shooter/core/files.lua` use oil.nvim for file path resolution and file management keymaps.
- Files: `lua/shooter/keymaps/oil.lua`, `lua/shooter/core/files.lua`
- Impact: Oil keymaps fail if oil.nvim is not installed. The `pcall(require, 'oil')` guard in `files.lua` handles this gracefully, but `keymaps/oil.lua` is set up unconditionally in `init.lua`.
- Migration plan: Guard `oil_keymaps.setup()` in `lua/shooter/init.lua` with a `pcall(require, 'oil')` check.

## Test Coverage Gaps

**No tests for tmux operations, send, or create modules:**
- What's not tested: The core send-to-AI workflow (`lua/shooter/tmux/operations.lua`, `lua/shooter/tmux/send.lua`, `lua/shooter/tmux/create.lua`) has no test coverage. These are the most critical paths in the plugin.
- Files: `lua/shooter/tmux/operations.lua`, `lua/shooter/tmux/send.lua`, `lua/shooter/tmux/create.lua`
- Risk: Regressions in the send pipeline go unnoticed. The iTerm2 workaround cannot be verified without real terminal integration tests.
- Priority: High

**No tests for commands.lua (735 lines):**
- What's not tested: The entire command registration and dispatch layer.
- Files: `lua/shooter/commands.lua`
- Risk: Commands could be registered with wrong options or break on argument parsing. Medium risk since commands mostly delegate to tested modules.
- Priority: Medium

**No tests for telescope pickers, actions, previewers, or helpers (beyond helpers_spec and toggle_panes_picker_spec):**
- What's not tested: `lua/shooter/telescope/pickers.lua` (465 lines), `lua/shooter/telescope/actions.lua` (225 lines), `lua/shooter/telescope/previewers.lua`.
- Files: `lua/shooter/telescope/pickers.lua`, `lua/shooter/telescope/actions.lua`, `lua/shooter/telescope/previewers.lua`
- Risk: Picker behavior regressions (sorting, filtering, multi-select) are caught late.
- Priority: Medium

**No tests for context resolvers, keymaps, config, utils, syntax, images:**
- What's not tested: Foundational modules that other code depends on.
- Files: `lua/shooter/context/resolvers.lua`, `lua/shooter/keymaps.lua`, `lua/shooter/config.lua`, `lua/shooter/utils.lua`, `lua/shooter/syntax.lua`, `lua/shooter/images.lua`
- Risk: Low individually, but `config.lua` and `utils.lua` are imported by nearly every module.
- Priority: Low (config and utils are simple, syntax is visual)

**Overall coverage: 37 test files for 85 source files (~44% file coverage).**

---

*Concerns audit: 2026-04-03*
