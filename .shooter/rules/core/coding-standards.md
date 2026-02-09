# Coding Standards

Universal coding standards for all languages and projects.

## Clarity

- Write clean, readable code; prefer clarity over cleverness
- Functions should do one thing and be short enough to understand at a glance
- Use meaningful, descriptive names for variables, functions, and files
- Code should read like prose — a new developer should follow the logic without comments

## Structure

- One concept per function; one responsibility per module
- Keep nesting shallow (max 2-3 levels); extract early returns or helper functions
- Order code top-down: public API first, helpers below
- Group related logic together; separate unrelated concerns

## Naming

- Variables: describe what it holds (`userCount`, not `n`)
- Functions: describe what it does (`fetchUserProfile`, not `getData`)
- Booleans: use `is`/`has`/`should` prefixes (`isActive`, `hasPermission`)
- Files: match the primary export or concept they contain

## Constants and Magic Values

- No magic numbers or strings — use named constants
- Group related constants in enums or constant objects
- Configuration values belong in config files, not scattered in code

## DRY and Abstraction

- DRY applies at 3+ repetitions; don't abstract after the first duplication
- Three similar lines of code beats a premature abstraction
- Prefer composition over inheritance
- Extract when you have a clear, stable interface — not before

## Error Handling

- Validate at system boundaries (API inputs, file reads, user data)
- Trust internal code — don't defensively check everything
- Fail fast with clear error messages
- Handle errors at the level that can do something useful about them
- Never swallow errors silently

## Code Hygiene

- No commented-out code — git history preserves everything
- No dead code; delete unused functions and imports
- Avoid premature optimization — measure first, optimize second
- TODO comments should be actionable and resolved promptly, or be removed
- Keep files under 200 lines; split when they grow beyond that

## Dependencies

- Prefer standard library over third-party when the gap is small
- Evaluate dependencies for maintenance status and bundle size
- Pin dependency versions for reproducible builds
- One package manager per project — no mixing npm/yarn/pnpm

## Script Organization

Utility scripts live in `scripts/` organized by language:

| Language   | Directory          |
|------------|--------------------|
| Bash/Shell | `scripts/shell/`   |
| Go         | `scripts/go/`      |
| Javascript | `scripts/js/`      |
| Lua        | `scripts/lua/`     |
| Python     | `scripts/python/`  |
| Rust       | `scripts/rust/`    |
| Typescript | `scripts/ts/`      |

This applies only to standalone utility scripts (build helpers, sync tools, etc.), not application source code.

Projects should have a `.envrc` file that adds `scripts/shell` to PATH:

```bash
PATH_add scripts/shell
```

## Script Naming Convention

All utility scripts must follow the naming pattern: `<alias>_<scriptname>.<ext>`

- `<alias>` is the project's short alias from the `.shooter/ALIAS` file
- `<scriptname>` is the descriptive name using kebab-case
- `<ext>` is the file extension matching the language

| Language   | Pattern                      | Example                  |
|------------|------------------------------|--------------------------|
| Bash/Shell | `<alias>_scriptname.sh`      | `ai_sync.sh`             |
| Go         | `<alias>_scriptname.go`      | `ops_deploy.go`          |
| Javascript | `<alias>_scriptname.js`      | `dev_build-assets.js`    |
| Lua        | `<alias>_scriptname.lua`     | `game_init-state.lua`    |
| Python     | `<alias>_scriptname.py`      | `hal_process-data.py`    |
| Rust       | `<alias>_scriptname.rs`      | `cli_parse-args.rs`      |
| Typescript | `<alias>_scriptname.ts`      | `scrape-data.ts`         |

This convention:
- Prevents naming collisions when scripts are added to PATH
- Makes script origin clear when running from any directory
- Enables automated validation via doctor-check scripts
