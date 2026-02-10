# Q&A

## 2026-02-10 05:15: How to send shots to Codex and Gemini CLIs?
**Theme:** _project

**Q:** How do Codex CLI and Gemini CLI accept input? Can shooter.nvim send shots to all 4 major agent CLIs (Claude, OpenCode, Codex, Gemini)?

**A:** All 4 providers already exist in `lua/shooter/providers/`. Key findings:

- **Claude**: `@filepath` via send-keys — works perfectly.
- **OpenCode**: `@filepath` + Escape (dismiss autocomplete) + Enter — works.
- **Codex**: `@filepath` triggers an interactive fuzzy popup in the TUI that can't be automated via send-keys. Current approach sends literal path without `@` — correct for automation. Caveat: pasting >1000 chars triggers placeholder. Process shows as `node` when npm-installed (not `codex`).
- **Gemini**: `@filepath` IS supported natively (pre-expands file content). Current provider reads file and pastes raw text — suboptimal and fragile (known multiline paste bugs). Should be updated to use `@filepath` like Claude.

**Action items:**
1. Update `gemini.lua` to use `send.send_file_reference()` instead of reading+pasting
2. Consider robust Codex process pattern: `codex|node.*codex` for npm users
3. All 4 CLIs are functional — Gemini is the only one needing a code change

## 2026-02-08 04:20: Can shooter.nvim live inside the shooter monorepo?

**Q:** Can the Neovim plugin be moved into `~/a/shooter/nvim/` and still be installable by package managers (lazy.nvim, packer, etc.)?

**A:** Technically possible but with major friction. No major Neovim package manager (lazy.nvim, mini.deps, rocks.nvim) natively supports installing from a subdirectory. lazy.nvim explicitly closed this as "not planned." The `vim.opt.rtp:append()` workaround has known bugs (rtp pollution, broken help tags, broken ftdetect, unintended file sourcing).

**Issues with monorepo approach:**
- Runtimepath expects `lua/`, `plugin/`, `doc/` at repo root — nested dirs aren't found
- Help tags, ftdetect, after-scripts all break
- LuaRocks requires rockspec at repo root
- Every user needs non-standard install config

**Options considered:**
1. CI auto-publish (monorepo source, auto-sync to standalone repo)
2. Keep separate repos (simplest, zero user friction)
3. Monorepo only (harder for users to install)
4. Git subtree (manual sync to standalone repo)

**Decision:** Keep `shooter.nvim` as its own separate repo. Users install normally with `{ "divramod/shooter.nvim" }`. Reference from monorepo via submodule or symlink if needed for development.
