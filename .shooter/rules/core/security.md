# Security Rules

## Secrets Management

- Never commit secrets, keys, tokens, or passwords to version control
- Use environment variables or secret managers for sensitive configuration
- Add secret patterns to `.gitignore` and use git pre-commit hooks to catch leaks
- Rotate any credential that was ever exposed, even briefly
- Use `.env.example` with placeholder values, never real secrets

## AI Agent Security

AI agents must never leak sensitive information through any persistent artifact.

### Commit Hygiene
- Never commit files containing real secrets, even temporarily — git history is permanent
- Before every commit, mentally scan staged changes for: API keys, tokens, passwords, absolute paths, email addresses, private IPs
- Use `$HOME` or `~` instead of absolute paths like `/Users/username/` or `/home/username/`
- If a secret was accidentally committed, it must be rotated AND removed from git history (not just deleted in a new commit)
- Connection strings, database URLs, and service endpoints go in `.env`, never in code

### Beads Content
- Never include real secrets, tokens, or credentials in bead titles, descriptions, notes, or comments
- Avoid absolute paths in beads — use relative paths or `~`
- Do not paste error messages containing secrets into bead fields
- When logging debug information to beads, redact any sensitive values first

### Context Files
- `.shooter/context.md` is committed — never include secrets
- Research artifacts in `.shooter/research/` are committed — redact sensitive data
- Decision logs in `.shooter/decisions.md` should not reference real credentials

### Pre-Commit Prevention
- Projects should use gitleaks or similar tools as pre-commit hooks
- The `.gitignore` should always include: `.env`, `.env.local`, `.env.*.local`, `*.pem`, `*.key`, `credentials.json`, `service-account.json`
- Use `.env.example` with placeholder values to document required environment variables
