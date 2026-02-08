# React Conventions

React-specific coding standards and best practices.

## Components

- Functional components only — no class components
- One component per file; file name matches component name
- Prefer composition over inheritance
- Keep components small and focused on one responsibility
- Extract sub-components when JSX exceeds ~50 lines

## Hooks

- Use custom hooks to extract reusable stateful logic
- Follow the Rules of Hooks: only call at top level, only in React functions
- Name custom hooks with `use` prefix: `useAuth`, `useFetchData`
- Keep hooks focused — one concern per hook
- Prefer `useReducer` over `useState` for complex state transitions

## State Management

- Collocate state with where it's used — lift only when necessary
- Use React Context for truly global state (theme, auth, locale)
- Avoid prop drilling beyond 2-3 levels — use context or composition
- Prefer server state libraries (TanStack Query) over manual fetch + useState

## Performance

- Memoize expensive computations with `useMemo`
- Stabilize callback references with `useCallback` when passed to memoized children
- Don't optimize prematurely — measure first with React DevTools Profiler
- Use `React.memo` sparingly and only with evidence of unnecessary re-renders
- Use `lazy()` and `Suspense` for code splitting

## Forms

- Prefer controlled components for forms
- Use form libraries (React Hook Form, Formik) for complex forms
- Validate on blur for individual fields, on submit for the full form
- Keep form state local unless it needs to persist across routes

## Patterns

- Use children prop and render props for flexible composition
- Prefer compound components for related UI groups
- Use ErrorBoundary components for graceful error handling
- Key lists with stable, unique identifiers — never array index

## Styling

- Prefer CSS Modules, Tailwind, or CSS-in-JS — be consistent per project
- Collocate styles with components
- Use design tokens for colors, spacing, typography

## Testing

- Test behavior, not implementation details
- Use React Testing Library — query by role, label, or text
- Test user interactions: clicks, typing, form submission
- Avoid testing internal state or lifecycle directly

## Accessibility

- Use semantic HTML elements (`button`, `nav`, `main`, `article`) over generic `div`s
- Add ARIA labels to interactive elements without visible text: `aria-label`, `aria-labelledby`
- Ensure all interactive elements are keyboard accessible — test with Tab, Enter, Escape
- Provide `alt` text for images; use empty `alt=""` for decorative images
- Maintain logical heading hierarchy (`h1` > `h2` > `h3`) — never skip levels
- Ensure sufficient color contrast (WCAG AA: 4.5:1 for text, 3:1 for large text)
- Test with screen readers (VoiceOver, NVDA) and browser accessibility tools
- Use `focus-visible` for keyboard focus styles without affecting mouse users
