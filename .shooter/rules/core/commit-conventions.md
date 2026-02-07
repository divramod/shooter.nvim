# Commit Conventions

Git commit standards for all repositories.

## Format

```
type(scope): description (vX.Y.Z)

Optional body explaining WHY, not WHAT.

Co-Authored-By: <name> <email>
```

## Subject Line

- Use conventional commits: `type(scope): description (vX.Y.Z)`
- Keep under **60 characters** (including version)
- Use imperative mood: "add feature" not "added feature"
- Lowercase after the colon
- End with version in parentheses: `(v0.2.1)`

## Types

| Type       | When to use                        |
|------------|------------------------------------|
| `feat`     | New feature or capability          |
| `fix`      | Bug fix                            |
| `refactor` | Code change that doesn't fix/add   |
| `docs`     | Documentation only                 |
| `chore`    | Maintenance, deps, config          |
| `test`     | Adding or updating tests           |
| `ci`       | CI/CD pipeline changes             |
| `perf`     | Performance improvement            |
| `style`    | Formatting, whitespace, lint fixes |

## Scope

- Use the module, package, or feature area: `feat(auth): add login`
- Use the project name for cross-cutting: `chore(ai): update rules`
- Omit scope only for truly global changes

## Body

- Separate from subject with a blank line
- Explain WHY the change was made, not WHAT changed (the diff shows that)
- Wrap at 72 characters
- Reference related issues or context

## Trailers

- **Co-Authored-By** (required for AI commits): `Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>`
- Place trailers after the body, separated by a blank line

## Version Bumping

Every repository has a `.shooter/VERSION` file containing the current SemVer version.

**Before every commit:**
1. Bump the version in `.shooter/VERSION` (patch only for AI agents)
2. Include the new version in the commit message subject line

**AI agents: PATCH ONLY**

AI agents must **only bump patch versions**. Minor and major version bumps are reserved for human decision-making.

| Change Type | Bump    | Who            | Example           |
|-------------|---------|----------------|-------------------|
| Breaking    | major   | **Human only** | `1.0.0` → `2.0.0` |
| Feature     | minor   | **Human only** | `1.0.0` → `1.1.0` |
| Fix/Other   | patch   | AI or Human    | `1.0.0` → `1.0.1` |

Even if an AI agent adds a new feature, it should bump **patch** only. The human will decide when to bump minor/major during review or release.

**Example workflow:**
```bash
# 1. Bump version
echo "0.2.1" > VERSION

# 2. Stage changes including VERSION
git add VERSION <other-files>

# 3. Commit with version in message
git commit -m "feat(auth): add login (v0.2.1)"
```

**Monorepos (Turborepo/Nx):**

For monorepo projects using Turborepo or Nx, also update the version in the root `package.json`:

```bash
# 1. Bump VERSION file
echo "0.2.1" > VERSION

# 2. Update package.json version (use npm or edit manually)
npm version 0.2.1 --no-git-tag-version

# 3. Stage both files
git add VERSION package.json <other-files>
```

The VERSION file remains the source of truth; package.json is kept in sync.

**Rust projects:**
For Rust projects, also update the version in `Cargo.toml`:

## Release Commits

Release commits follow a special format. Minor and major bumps are only done via releases:

- Format: `chore(release): vX.Y.Z` (no Co-Authored-By — script-driven)
- Created by `shooter:release` skill, never manually
- AI agents continue using patch bumps for regular work commits
- Release commits include: VERSION bump, CHANGELOG entry, version file sync
- A git tag `vX.Y.Z` is created alongside each release commit

## Rules

- One logical change per commit — don't mix refactoring with features
- Never commit broken code to main
- Squash fixup commits before merge
- Rebase feature branches; merge to main
- Always bump VERSION before committing
