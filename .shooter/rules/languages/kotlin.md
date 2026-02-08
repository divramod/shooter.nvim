# Kotlin Conventions

Kotlin-specific coding standards and best practices.

## Data and Types

- Use `data class` for value types and DTOs
- Use `sealed class`/`sealed interface` for restricted hierarchies
- Prefer `object` for singletons over manual implementation
- Use `enum class` for fixed sets of values
- Prefer `value class` (inline) for type-safe wrappers

## Null Safety

- Avoid `!!` (not-null assertion) — use safe calls and elvis operator
- Use `?.let { }` for nullable transformations
- Use `?:` (elvis) for default values: `val name = input ?: "default"`
- Use `requireNotNull()` or `checkNotNull()` only at boundaries with clear messages
- Platform types from Java: annotate or wrap immediately

## Functions

- Use expression body for short functions: `fun double(x: Int) = x * 2`
- Use named arguments for clarity when calling functions with multiple parameters
- Use default parameter values over function overloads
- Prefer extension functions for adding behavior to existing types

## Collections

- Use `listOf`, `mapOf`, `setOf` for immutable collections (default choice)
- Use `mutableListOf` only when mutation is required
- Prefer `sequence {}` for large collection chains (lazy evaluation)
- Use destructuring: `val (name, age) = person`

## Coroutines

- Use coroutines for async work — never raw callbacks
- Use `suspend` functions for sequential async code
- Use `Flow` for reactive streams
- Use structured concurrency: launch in a `CoroutineScope`
- Handle cancellation properly — check `isActive` in long-running loops

## Code Style

- Prefer `when` over `if-else` chains for multiple conditions
- Use `apply`, `let`, `also`, `run` scope functions appropriately
- Use `require()` and `check()` for preconditions
- Trailing commas in multi-line lists and function calls

## Tooling

- Use `ktlint` for formatting
- Use `detekt` for static analysis
- Gradle with Kotlin DSL (`build.gradle.kts`)
- Target JVM 17+ for new projects

## Testing

- Use JUnit 5 with Kotlin extensions
- Use `MockK` for mocking (Kotlin-native, supports coroutines)
- Use backtick function names for readable test names: `` `should return user when found` ``
