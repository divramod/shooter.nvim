# Codex/Gemini tmux target support

## Scope
Enable Shooter to detect and target tmux panes running Codex and Gemini CLIs, including indexed sends (`ShoShotSend2+`, multi-shot sends), and keep behavior consistent with existing providers.

## Plan
1. Confirm root cause in provider detection and pane indexing path.
2. Add providers for `codex` and `gemini`:
   - identity + process pattern
   - file reference send behavior compatible with existing generic sender
   - shot/multishot message builders and provider metadata
3. Register providers in `lua/shooter/providers/init.lua`.
4. Extend AI startup support in `lua/shooter/tmux/create.lua`:
   - provider commands table
   - display-name mapping
   - interactive selection prompt entries
5. Update/extend tests in `tests/providers/init_spec.lua` for registration and pattern assertions.
6. Run verification tests and fix regressions.

## Verification
- Provider tests pass.
- Pattern list includes `codex` and `gemini`.
- No breakage in existing `claude`/`opencode` flows.

## Results
- Added provider modules: `codex`, `gemini`.
- Registered both providers in `lua/shooter/providers/init.lua`.
- Updated tmux creation/provider prompt flow to include Codex and Gemini commands.
- Updated AI detection messaging to be provider-generic.
- Extended provider tests and verified:
  - `nvim --headless -c "PlenaryBustedDirectory tests/providers/ {minimal_init = 'tests/minimal_init.lua'}" -c qa`
  - Result: 10 passing, 0 failing in provider suite.
- Additional tmux suite run showed unrelated pre-existing failures in:
  - `tests/tmux/renumber_helper_spec.lua`
  - `tests/tmux/create_spec.lua`
