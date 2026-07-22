# Project Rules — Example

This is a per-project AGENTS.md example. It merges over global ~/.config/opencode/AGENTS.md.

## Project Context

- **Stack:** Next.js 15 + Tailwind + Prisma
- **Node:** v22 via .nvmrc, fnm
- **Tests:** Vitest + Playwright
- **Lint:** Biome
- **Build:** `npm run build`

## Conventions

- Components in `src/components/`, kebab-case files, PascalCase components
- API routes in `src/app/api/`
- Use `~/` alias for `src/`
- Prefer server components, client only when needed
- Tests co-located `*.test.ts` or in `__tests__/`

## Do

- Run `npm run lint && npm run typecheck && npm test` before marking task complete
- Use existing UI components from `src/components/ui/`
- Check `docs/` for product behavior

## Don't

- Don't add new deps without checking existing (use `npm ls`)
- Don't commit `.env` files
- Don't break existing API contracts without migration

## High-Autonomy Still Applies

Same as global: make reasonable assumptions, batch edits, fix related failures, final report with what changed + verified + commit msg.

For this project specifically: when adding features, always check existing similar feature pattern first via @explore.
