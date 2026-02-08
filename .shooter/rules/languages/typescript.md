# TypeScript Conventions

TypeScript-specific coding standards and best practices.

## Compiler Settings

- Always use strict mode: `"strict": true` in tsconfig
- Enable `noUncheckedIndexedAccess` for safer array/object access
- Target the latest ES version your runtime supports

## Variables and Types

- Prefer `const` over `let`; never use `var`
- Use explicit types for function signatures (params and return)
- Let TypeScript infer types for local variables and simple assignments
- Use `unknown` over `any` — narrow with type guards
- Prefer `interface` over `type` for object shapes (interfaces merge and extend better)
- Use `type` for unions, intersections, and computed types

## Null Handling

- Prefer nullish coalescing (`??`) over logical OR (`||`) for defaults
- Use optional chaining (`?.`) for deep property access
- Avoid non-null assertions (`!`) — narrow the type instead
- Use `strictNullChecks` (included in strict mode)

## Functions

- Use arrow functions for callbacks and inline logic
- Use named function declarations for top-level and exported functions
- Prefer `readonly` parameters for objects that shouldn't be mutated
- Use discriminated unions over function overloads when possible

## Modules and Imports

- Use ES modules (`import`/`export`), never CommonJS in new code
- Use barrel exports (`index.ts`) sparingly — they hurt tree-shaking
- Prefer named exports over default exports
- Co-locate types with the code that uses them

## Patterns

- Use `as const` for literal type inference
- Prefer `Record<K, V>` over `{ [key: string]: V }`
- Use template literal types for string patterns
- Exhaustive checks with `never` in switch defaults

## Tooling

- Prefer `pnpm` as package manager
- Use `tsx` or `ts-node` for running scripts
- Biome or ESLint + Prettier for linting and formatting
- Use path aliases (`@/`) for cleaner imports in larger projects

## Testing

- Use Vitest for unit tests
- Prefer `describe`/`it` block structure
- Type-check test files — don't use `@ts-ignore` in tests
- Mock at module boundaries, not internal functions
