# Decisions

## 2026-02-09 18:43: Add Codex and Gemini as first-class tmux providers
- Added `codex` and `gemini` provider modules (same send/message contract as existing providers).
- Registered both process patterns so pane indexing (`send ...2+`) includes Codex/Gemini panes during detection.
- Kept provider file-send behavior on shared `@filepath` flow to minimize behavioral divergence.
