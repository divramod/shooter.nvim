# Shooter Template Variables

These variables are available in all shooter template files. Use the `{{variable_name}}` syntax to include them.

## Shot Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{shot_num}}` | Current shot number | `117` |
| `{{shot_nums}}` | Comma-separated shot numbers (multishot only) | `1, 2, 3` |

## File Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{file_path}}` | Full absolute path to the file | `/Users/mod/dev/plans/prompts/20260118_0516_nvim-commands.md` |
| `{{file_name}}` | Filename with extension | `20260118_0516_nvim-commands.md` |
| `{{file_title}}` | Title from the file's first `#` heading | `2026-01-18 - nvim next action commands` |

## Repository Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{repo_name}}` | Repository name from git remote | `divramod/dev` |
| `{{repo_path}}` | Git root path (absolute) | `/Users/mod/dev` |

## Template Priority

Templates are loaded in this order (first found wins):

1. **Project-specific**: `./.shooter.nvim/shooter-context-instructions.md`
2. **Global**: `~/.config/shooter.nvim/shooter-context-instructions.md`
3. **Plugin fallback**: `templates/shooter-context-instructions.md`

## Usage Example

Create a custom template at `~/.config/shooter.nvim/shooter-context-instructions.md`:

```markdown
# context
1. this is shot {{shot_num}} of "{{file_title}}" in {{repo_name}}.
2. file: {{file_name}} at {{file_path}}
3. repo root: {{repo_path}}
4. implement this shot now.
```
