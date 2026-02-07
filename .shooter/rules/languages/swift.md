# Swift Conventions

Swift-specific coding standards and best practices.

## API Design

- Follow the Swift API Design Guidelines
- Name methods for their use site: `array.remove(at: index)` not `array.removeAt(index)`
- Prefer clarity over brevity
- Use grammatical English phrases: `x.insert(y, at: z)` reads as "insert y at z"

## Value Types

- Use `struct` by default — only use `class` when reference semantics are needed
- Use `enum` for variants and state machines
- Prefer value semantics for data models
- Use `class` for identity-based objects (view controllers, coordinators)

## Control Flow

- Use `guard` clauses for early returns — keep the happy path unindented
- Prefer `guard let` over `if let` when the unwrapped value is used in the remaining scope
- Use `defer` for cleanup that must happen regardless of exit path
- Prefer `switch` with exhaustive cases over `if-else` chains

## Optionals

- Never force-unwrap (`!`) except in tests or known-safe contexts
- Use `if let`/`guard let` for unwrapping
- Use `??` for default values
- Use `map` and `flatMap` on optionals for transformations
- Prefer optional chaining over nested unwrapping

## Concurrency

- Prefer `async`/`await` over completion handlers
- Use `Task` for launching async work from synchronous contexts
- Use `actor` for thread-safe mutable state
- Use `@Sendable` closures for cross-isolation boundaries
- Prefer structured concurrency (`async let`, `TaskGroup`)

## Error Handling

- Use `throws` and `do-catch` for recoverable errors
- Define domain-specific error types conforming to `Error`
- Use `Result` when you need to store or pass errors
- Prefer `try?` for optional error handling when the error details don't matter

## Protocols

- Use protocol-oriented design: define behavior through protocols
- Prefer protocol extensions for default implementations
- Keep protocols focused — prefer multiple small protocols over one large one
- Use `some Protocol` (opaque types) for return types

## Tooling

- Use SwiftLint for style enforcement
- Use Swift Package Manager for dependency management
- Use Xcode's built-in formatter or swift-format
- Target the latest stable Swift version

## Testing

- Use XCTest or Swift Testing framework
- Prefer protocol-based dependency injection for testability
- Use `@testable import` for internal access in tests
