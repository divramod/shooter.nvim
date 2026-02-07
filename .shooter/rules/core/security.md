# Security Rules

Security practices required across all projects and languages. These rules align with the [OWASP Top 10 2021](https://owasp.org/Top10/) security risks.

## Secrets Management

- Never commit secrets, keys, tokens, or passwords to version control
- Use environment variables or secret managers for sensitive configuration
- Add secret patterns to `.gitignore` and use git pre-commit hooks to catch leaks
- Rotate any credential that was ever exposed, even briefly
- Use `.env.example` with placeholder values, never real secrets

## Input Validation

*Addresses A03:2021 Injection*

- Validate all user input at system boundaries
- Never trust client-side validation alone — always validate server-side
- Use allowlists over denylists for input validation
- Reject unexpected input; don't try to sanitize it into validity
- Validate types, ranges, lengths, and formats

## Output Security

*Addresses A03:2021 Injection*

- Sanitize all output to prevent XSS (cross-site scripting)
- Use context-aware encoding (HTML, URL, JavaScript, CSS)
- Set `Content-Security-Policy` headers
- Escape user-generated content before rendering

## Database Security

*Addresses A03:2021 Injection*

- Use parameterized queries — never concatenate SQL strings
- Apply principle of least privilege to database accounts
- Never expose raw database errors to users
- Sanitize and validate all query parameters

## Authentication and Authorization

*Addresses A01:2021 Broken Access Control, A07:2021 Identification and Authentication Failures*

- Follow principle of least privilege for all access
- Use established auth libraries — never roll your own crypto
- Hash passwords with bcrypt/argon2 — never SHA/MD5
- Implement rate limiting on auth endpoints
- Use short-lived tokens; implement refresh token rotation

## Dependency Security

*Addresses A06:2021 Vulnerable and Outdated Components*

- Keep dependencies updated; automate vulnerability scanning
- Audit new dependencies before adding them
- Use lockfiles for reproducible builds
- Pin versions in production

## Code Safety

*Addresses A03:2021 Injection, A08:2021 Software and Data Integrity Failures*

- No `eval()` or dynamic code execution from user input
- No deserialization of untrusted data
- Avoid shell command injection — use library APIs instead of exec
- Disable debug mode and verbose errors in production

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
- Run `shooter:fix-security-holes` periodically to audit beads content

### Context Files
- `.shooter/context-ai-learnings.md` and `.shooter/context-human-learnings.md` are committed — never include secrets
- Research artifacts in `.shooter/research/` are committed — redact sensitive data
- Decision logs in `.shooter/decisions.md` should not reference real credentials

### Pre-Commit Prevention
- Projects should use gitleaks or similar tools as pre-commit hooks
- The `.gitignore` should always include: `.env`, `.env.local`, `.env.*.local`, `*.pem`, `*.key`, `credentials.json`, `service-account.json`
- Use `.env.example` with placeholder values to document required environment variables

## Infrastructure

*Addresses A05:2021 Security Misconfiguration, A09:2021 Security Logging and Monitoring Failures*

- HTTPS everywhere — no exceptions
- Set secure cookie flags: `HttpOnly`, `Secure`, `SameSite`
- Implement CORS with specific origins, not wildcards
- Log security events; never log sensitive data
