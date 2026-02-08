# Rust Conventions

Rust-specific coding standards and best practices.

## Error Handling

- Prefer `Result<T, E>` over `panic!` — reserve panics for truly unrecoverable states
- Use the `?` operator for error propagation
- Use `thiserror` for library error types (derives `std::error::Error`)
- Use `anyhow` for application error handling (when you don't need typed errors)
- Provide context with `.context()` or `.with_context(|| ...)`

## Ownership and Borrowing

- Prefer borrowing (`&T`) over ownership when you don't need to own the data
- Use `Clone` intentionally, not as an escape hatch from the borrow checker
- Prefer `&str` over `String` in function parameters
- Use `Cow<str>` when you might or might not need to own

## Patterns

- Prefer iterators over index-based loops — they're zero-cost and more expressive
- Use `map`, `filter`, `collect` chains for data transformations
- Prefer `match` with exhaustive patterns over `if let` chains
- Use `#[must_use]` on functions where ignoring the return value is likely a bug
- Derive standard traits: `Debug`, `Clone`, `PartialEq` when appropriate

## Types

- Use newtypes to enforce invariants: `struct UserId(u64)`
- Prefer enums for state machines and variant types
- Use `Option<T>` instead of sentinel values
- Implement `Display` for user-facing output, `Debug` for developer output

## Concurrency

- Prefer `tokio` for async runtime
- Use `Arc<Mutex<T>>` sparingly — prefer message passing with channels
- Mark shared state explicitly with `Send` + `Sync` bounds
- Use `rayon` for data parallelism


## Unsafe Code

- Minimize unsafe blocks — keep them as small as possible with clear boundaries
- Document safety invariants with `// SAFETY:` comments explaining why the code is sound
- Prefer safe abstractions — wrap unsafe code in safe APIs with invariants enforced at the boundary
- Use `#[deny(unsafe_op_in_unsafe_fn)]` to require explicit unsafe blocks inside unsafe functions
- Consider safer alternatives: `std::ptr::NonNull` over raw pointers, `std::mem::MaybeUninit` over uninitialized memory
- Audit unsafe code more carefully in reviews — verify all safety invariants are upheld
- Avoid `unsafe` for performance unless profiling proves it necessary

## Tooling

- Run `cargo fmt` always — format on save
- Use `clippy` with `-D warnings` (deny all warnings)
- Run `cargo test` before every commit
- Use `cargo deny` for dependency auditing
- Use `cargo doc --open` to verify documentation

## Project Structure

- Use workspace (`Cargo.toml` with `[workspace]`) for multi-crate projects
- Separate binary and library crates: `src/main.rs` + `src/lib.rs`
- Feature flags for optional functionality
- Keep `mod.rs` files minimal — prefer file-per-module layout

## Documentation

- Doc comments (`///`) on all public items
- Include examples in doc comments — they run as tests
- Use `#![deny(missing_docs)]` for libraries
