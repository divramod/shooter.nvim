# Next.js Conventions

Next.js-specific coding standards and best practices.

## Routing

- Use App Router (`app/`) — not Pages Router (`pages/`)
- Use file-system routing conventions: `page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`
- Use route groups `(group)` for organization without URL impact
- Use dynamic routes with `[param]` and catch-all with `[...slug]`
- Collocate route-specific components alongside their `page.tsx`

## Server vs Client

- Server Components by default — only add `'use client'` when you need:
  - Event handlers (`onClick`, `onChange`)
  - Browser APIs (`window`, `localStorage`)
  - React hooks (`useState`, `useEffect`)
- Keep `'use client'` boundary as low in the tree as possible
- Pass server data down to client components as props

## Data Fetching

- Use `async` Server Components for data fetching
- Use Server Actions for mutations (forms, POST requests)
- Use `fetch` with built-in caching and revalidation options
- Prefer `revalidatePath`/`revalidateTag` for cache invalidation
- Use `loading.tsx` for streaming and progressive rendering

## Performance

- Use `next/image` for all images — automatic optimization, lazy loading, sizing
- Use `next/font` for font loading — no layout shift
- Use `next/link` for client-side navigation
- Dynamic imports with `next/dynamic` for code splitting heavy components
- Use `generateStaticParams` for static generation of dynamic routes

## Metadata and SEO

- Use the Metadata API (`export const metadata` or `generateMetadata`)
- Define metadata in layouts for inherited values, pages for specific values
- Include Open Graph and Twitter card metadata for shared pages
- Use `robots.ts` and `sitemap.ts` for search engine optimization

## Error Handling

- Use `error.tsx` for route-level error boundaries
- Use `not-found.tsx` for 404 pages
- Use `global-error.tsx` for root layout errors
- Server Actions should return typed error states, not throw

## Middleware

- Use `middleware.ts` at the project root for request-level logic
- Keep middleware fast — it runs on every matching request
- Use matcher config to limit middleware to specific paths

## Project Structure

```
app/
  (auth)/
    login/page.tsx
    register/page.tsx
  (dashboard)/
    layout.tsx
    page.tsx
  api/          # Route handlers only when Server Actions won't work
  globals.css
  layout.tsx    # Root layout
```

## Environment Variables

- Use `NEXT_PUBLIC_` prefix only for client-exposed variables
- Server-only secrets: no prefix, accessed only in server code
- Validate env vars at build time with `@t3-oss/env-nextjs` or similar
