# Frontend Rules (apps/web, apps/admin, apps/space, packages/**)

- React 18 functional components only -- no class components
- TypeScript strict mode -- no `any`, no `as any`, no `@ts-ignore`
- MobX for state -- use `observer()` wrapper, actions for mutations, `makeObservable`
- TailwindCSS for styling -- no CSS modules, no styled-components
- Named exports preferred (except page-level route components)
- One concern per file -- aim for max 300 lines
- All props must be typed with interfaces
- Use `workspace:*` for internal @plane/* packages, `catalog:` for external deps
- Formatting with oxfmt, linting with OxLint
- camelCase for variables/functions, PascalCase for components/types
- API calls go through `packages/services/` -- never call axios directly from components
- Use SWR hooks for data fetching patterns
- Use React Router v7 conventions for routing
