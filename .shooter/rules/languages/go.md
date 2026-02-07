# Go Conventions

Go-specific coding standards and best practices.

## Philosophy

- Follow Effective Go and the Go Proverbs
- A little copying is better than a little dependency
- Clear is better than clever
- Don't panic

## Error Handling

- Always check errors — never use `_` to discard them
- Wrap errors with context: `fmt.Errorf("fetching user %d: %w", id, err)`
- Use `errors.Is` and `errors.As` for error matching
- Return errors to callers; only log at the top level
- Define sentinel errors for expected conditions: `var ErrNotFound = errors.New("not found")`

## Context

- Use `context.Context` as the first parameter for functions that do I/O
- Never store contexts in structs
- Use context for cancellation, deadlines, and request-scoped values
- Derive child contexts with `context.WithCancel` or `context.WithTimeout`

## Interfaces

- Keep interfaces small: 1-3 methods
- Define interfaces where they are used, not where they are implemented
- Accept interfaces, return structs
- Use the standard `io.Reader`, `io.Writer` patterns when possible

## Naming

- Short, clear names: `srv` not `server` for local vars, `Server` for exported types
- Acronyms in caps: `HTTPClient`, `userID`
- Package names are lowercase, single-word: `auth`, not `authentication`
- Avoid stuttering: `auth.Client` not `auth.AuthClient`

## Concurrency

- Don't communicate by sharing memory; share memory by communicating
- Use goroutines + channels for concurrent work
- Always clean up goroutines — avoid leaks
- Use `sync.WaitGroup` for fan-out/fan-in
- Prefer `sync.Mutex` over channels for simple state protection

## Testing

- Prefer table-driven tests for multiple cases
- Use `testify/assert` or standard `testing` package
- Test file naming: `foo_test.go` alongside `foo.go`
- Use `t.Helper()` in test helpers
- Use `t.Parallel()` for independent tests

## Tooling

- `gofmt` is non-negotiable — run on save
- `go vet` and `staticcheck` for additional linting
- Use `golangci-lint` for comprehensive checks
- Modules with `go.mod` — never use GOPATH mode

## Project Structure

- Follow the standard Go project layout
- `cmd/` for entry points, `internal/` for private packages
- Keep `main.go` minimal — delegate to library code
