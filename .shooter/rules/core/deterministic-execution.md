# Deterministic Execution

AI agents are non-deterministic; shell scripts are deterministic. For critical paths (setup, config, onboarding), extract every deterministic step into a script. AI handles only user interaction and ambiguous decisions.

## Script vs AI Ownership

| In Scripts | In AI |
|-----------|-------|
| File/dir existence checks, migrations | Asking user for input |
| Config reading, writing, validation | Interpreting ambiguous context |
| Version bumping, formatting | Deciding between unclear approaches |
| Git operations (stage, commit, push) | Presenting options to user |
| Detection/discovery (themes, deps, tools) | Routing on script output prefixes |
| Any clear if/then/else logic | — |

## Script Contract

1. **Prefixed output** — every line starts with: `ok:`, `skip:`, `created:`, `error:`, `missing:`, `detected:`
2. **Exit codes** — 0=success, 1=usage error, 2=precondition failure
3. **Idempotent** — safe to run multiple times
4. **Accept `--repo-root`** — never assume working directory
5. **Self-contained** — handle edge cases internally
