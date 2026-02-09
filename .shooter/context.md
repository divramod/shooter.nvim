# Project Context

## Human Notes
<!-- Human-owned: add project-specific instructions, preferences, patterns here -->


<!-- This file is for human-written project context and learnings. AI agents should NEVER edit this file. -->

## AI Learnings
<!-- AI-discovered: add patterns, build commands, conventions here -->
<!-- When any file or folder is added, renamed, updated, or deleted in .shooter/, update .shooter/README.md to reflect the change. -->

- Global config is at `~/.config/shooter/nvim/config.yaml` (migrated from `~/.config/shooter.nvim/`). All config values must be listed in `ext_config.DEFAULTS`. Project-local overrides go to `<repo>/.shooter/cfg/nvim/config.yaml`.
- All path accessors for global config are centralized in `lua/shooter/core/ext_config.lua`. Never hardcode `~/.config/shooter.nvim/` or `~/.config/shooter/nvim/` elsewhere.
- Config auto-reloads on `BufWritePost` of `config.yaml` files matching shooter paths.
- For Codex/Gemini shot dispatch, root cause can be `@filepath` parsing (not path location). Keep global bullets under `~/.config/shooter/nvim/bullets`; provider-specific send logic should use literal file paths when `@` hangs.

<!-- This file is for AI-generated project context and learnings. AI agents can update this file. -->
