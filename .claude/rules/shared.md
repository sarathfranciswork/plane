# Shared / Cross-Cutting Rules

- `packages/` -- shared code consumed by ALL apps. Never import app-specific code here.
- `packages/types/` -- interfaces only. No implementation. No runtime deps.
- `packages/services/` -- Axios-based API client. Organized by domain.
- `packages/editor/` -- TipTap editor. Extensions go in extensions/.
- `.env` files -- NEVER commit. Use `.env.example` as template.
- Environment variables -- access via `import.meta.env.VITE_*` (frontend) or `os.environ.get()` (backend)
- Docker services -- 13 containers in production. Use docker-compose-local.yml for dev.
- Git branch -- main branch is `preview`. Always push to `preview`.
- Monorepo -- pnpm workspaces. Use `pnpm turbo run <cmd> --filter=<pkg>` to target specific packages.
