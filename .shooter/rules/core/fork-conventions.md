# Fork Conventions

Rules for working with forked repositories.

## Directory Convention

All forked repositories live under `{{shooter:paths.forks}}/` in a flat layout:

```
{{shooter:paths.forks}}/<repo-name>/
```

Examples:
- `{{shooter:paths.forks}}/beads/` — fork of github.com/steveyegge/beads
- `{{shooter:paths.forks}}/beads_viewer/` — fork of github.com/Dicklesworthstone/beads_viewer

## Fork Setup

When forking a repo:
1. Fork on GitHub via `gh repo fork`
2. Clone to `{{shooter:paths.forks}}/<repo>`
3. Add as a theme in the **current project's** `.shooter/themes.json`
4. Do NOT run `sho:prj-setup-infrastructure` or initialize beads in the fork — keep forks clean for upstream PRs
5. Do NOT register forks in `~/.config/shooter/repos.json`

## Theme Integration

Forked repos are added as themes in the project that uses them. The theme entry uses a relative path from the project root:

```json
{ "slug": "<short-name>", "title": "<project>/<short-name>", "path": "<relative-path-to-fork>", "shotfile": ".shooter/shotfiles/<short-name>.md" }
```

The slug should be a short, memorable name (e.g., `bv` for beads_viewer, `beads` for beads).

## Beads for Fork Work

Beads for work on forked repos are created in the **parent project** (the one that depends on the fork), NOT in the fork itself. This keeps forks clean and avoids confusing upstream PRs with shooter artifacts.

## Remotes Convention

Forked repos always have two remotes:
- `origin` — your personal fork (`git@github.com:<your-username>/<repo>.git`)
- `upstream` — the original repo (`git@github.com:<owner>/<repo>.git`)

## Rules

- Forks ALWAYS go to `{{shooter:paths.forks}}/<repo-name>/` — never nested paths like `{{shooter:paths.forks}}/<owner>/<repo>/`
- Use `sho:dev-fork-repo` command when available
- Do NOT run `sho:prj-setup-infrastructure` in forks — keep them clean for upstream contributions
- Do NOT register forks in `~/.config/shooter/repos.json`
- Do NOT initialize beads in forks — track work in the parent project's beads
- Add as theme in the project that depends on the fork
- Keep `origin` and `upstream` remotes in sync
