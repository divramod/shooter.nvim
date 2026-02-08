# Shell Script Conventions

Bash and shell scripting standards.

## Script Header

Every script must have a header comment block with these sections in order:

1. **Description** — what the script does (1-3 lines)
2. **Usage** — how to invoke it with flags and arguments
3. **Steps** — numbered list of what the script does, one step per line

```bash
#!/usr/bin/env bash
set -euo pipefail

# Short description of what the script does
#
# Usage: script_name.sh [--flag <value>]
#   --flag: description
#
# Steps:
#   1. Parse arguments
#   2. Validate preconditions
#   3. Do the main work
#   4. Output results
```

The Steps section is mandatory. It gives readers an instant overview of the script's logic without reading the implementation.

## Shebang and Safety

- Always start with: `#!/usr/bin/env bash`
- Always set: `set -euo pipefail`
  - `-e`: exit on error
  - `-u`: error on undefined variables
  - `-o pipefail`: catch errors in piped commands
- Use `set -x` for debugging (remove before committing)

## Quoting

- Quote all variable expansions: `"$var"` not `$var`
- Quote command substitutions: `"$(command)"`
- Use `"${array[@]}"` to expand arrays
- Only omit quotes in arithmetic contexts: `$(( count + 1 ))`

## Conditionals

- Use `[[ ]]` over `[ ]` — it handles word splitting and glob expansion safely
- Use `(( ))` for arithmetic comparisons
- Use `||` and `&&` inside `[[ ]]`, not `-a` and `-o`
- Pattern matching: `[[ "$str" == *.txt ]]`

## Variables

- Use `local` for function variables
- Use `readonly` for constants: `readonly CONFIG_DIR="/etc/myapp"`
- Use `UPPER_SNAKE_CASE` for exported/environment variables
- Use `lower_snake_case` for local variables
- Use `${var:-default}` for default values

## Functions

- Use functions for any reusable logic
- Define with: `function_name() { ... }` (no `function` keyword)
- Always use `local` for variables inside functions
- Return status codes, not strings — use stdout for output
- Document functions with a comment header

## Input/Output

- Use `printf` over `echo` for portable output
- Redirect stderr for error messages: `printf "error: %s\n" "$msg" >&2`
- Use heredocs for multi-line text
- Prefer long option flags: `--verbose` over `-v` for readability in scripts

## Error Handling

- Use `trap` for cleanup: `trap cleanup EXIT`
- Check command existence: `command -v tool >/dev/null 2>&1`
- Provide clear error messages with context
- Exit with meaningful status codes (not just 0 and 1)

## Tooling

- Run `shellcheck` on all scripts — no exceptions
- Use `shfmt` for formatting
- Make scripts executable: `chmod +x script.sh`

## Best Practices

- Avoid parsing `ls` output — use globs or `find`
- Prefer `mktemp` for temporary files
- Use `command -v` over `which` for portability
- Avoid subshells when a block redirect will do
- Keep scripts under 200 lines — extract to functions or separate scripts
