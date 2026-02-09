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
- Pending implementation.
