# Q&A

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
