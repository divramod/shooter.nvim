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

Every project must have a `scripts/` directory at the repository root. The `scripts/shell/` subdirectory is **mandatory** — it must always exist, even if initially empty. Other language subdirectories are added as needed.

| Language   | Directory          | Required |
|------------|--------------------|----------|
| Bash/Shell | `scripts/shell/`   | **Yes**  |
| Go         | `scripts/go/`      | No       |
| Javascript | `scripts/js/`      | No       |
| Lua        | `scripts/lua/`     | No       |
| Python     | `scripts/python/`  | No       |
| Rust       | `scripts/rust/`    | No       |
| Typescript | `scripts/ts/`      | No       |

This applies only to standalone utility scripts (build helpers, sync tools, etc.), not application source code.

Projects must have a `.envrc` file that adds `scripts/shell` to PATH:

```bash
PATH_add scripts/shell
```

## Script Naming Convention

All utility scripts must follow the naming pattern: `<alias>_<verb-description>.<ext>`

- `<alias>` is the project's short alias from the `.shooter/ALIAS` file
- `<verb-description>` is a kebab-case name that **always starts with a verb** (e.g., `sync-data`, `build-assets`, `ensure-config`)
- `<ext>` is the file extension matching the language

| Language   | Pattern                              | Example                        |
|------------|--------------------------------------|--------------------------------|
| Bash/Shell | `<alias>_<verb-description>.sh`      | `sho_ensure-directories.sh`    |
| Go         | `<alias>_<verb-description>.go`      | `ops_deploy-services.go`       |
| Javascript | `<alias>_<verb-description>.js`      | `dev_build-assets.js`          |
| Lua        | `<alias>_<verb-description>.lua`     | `game_init-state.lua`          |
| Python     | `<alias>_<verb-description>.py`      | `hal_process-data.py`          |
| Rust       | `<alias>_<verb-description>.rs`      | `cli_parse-args.rs`            |
| Typescript | `<alias>_<verb-description>.ts`      | `web_generate-sitemap.ts`      |

**Good verb-first names:** `ensure-beads`, `verify-setup`, `sync-themes`, `clean-cache`, `build-dist`
**Bad names:** `beads-ensure` (noun-first), `setup` (no verb), `data` (no verb, no description)

This convention:
- Prevents naming collisions when scripts are added to PATH
- Makes script origin clear when running from any directory
- Makes the script's action immediately obvious from the filename
- Enables automated validation via doctor-check scripts
