# Decisions

## 2026-02-10 04:43: Send Gemini shot files as content, not path refs
- Live reproduction showed Gemini accepts `@/path` but may stall while attempting restricted `ReadFile` on global bullet paths outside workspace.
- Sending absolute bare paths is treated as an unknown slash command by Gemini.
- Chosen approach: for Gemini provider, read the shot temp file locally and send its content to the pane directly.

## 2026-02-10 04:41: Revert Gemini to @filepath send syntax
- Live pane validation showed Gemini treats a bare absolute path as a slash command (`Unknown command`).
- `@/absolute/path` is accepted by Gemini as a file reference in the same session.
- Keep Codex-specific no-`@` behavior, but restore Gemini to shared `@filepath` sending.

## 2026-02-09 20:46: Use literal path sends for Gemini shot files
- User confirmed Gemini/Codex failure mode is triggered by `@filepath`, not by external location.
- Preserve global bullets directory design (`~/.config/shooter/nvim/bullets`) instead of copying into repo paths.
- Gemini provider now sends literal file paths (no `@`) to match the Codex fix strategy.

## 2026-02-09 18:43: Add Codex and Gemini as first-class tmux providers
- Added `codex` and `gemini` provider modules (same send/message contract as existing providers).
- Registered both process patterns so pane indexing (`send ...2+`) includes Codex/Gemini panes during detection.
- Kept provider file-send behavior on shared `@filepath` flow to minimize behavioral divergence.
