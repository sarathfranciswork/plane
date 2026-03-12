# Commit and Push Workflow

1. Run frontend lint: `pnpm check:lint`
2. Run frontend typecheck: `pnpm check:types`
3. Run Python lint (if backend changed): `cd apps/api && python -m ruff check .`
4. Run Python tests (if backend changed): `cd apps/api && python -m pytest --tb=short -q`
5. Stage changes: `git add <specific files>`
6. Commit: `git commit -m "feat(scope): description"`
7. Push: `git push origin preview`

Commit message prefixes:

- feat: new feature
- fix: bug fix
- refactor: code restructure
- test: adding tests
- chore: maintenance, config, deps
- docs: documentation updates

Scopes: web, api, admin, space, live, editor, ui, propel, types, services, store, deps
