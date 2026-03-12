# Testing Rules

- Frontend: OxLint + TypeScript type checking via `pnpm check`
- Backend: pytest for Django tests, ruff for Python linting
- Live server: vitest for unit tests
- Run `pnpm check` before every frontend commit
- Run `python -m pytest` before every backend commit
- Test files go next to source: `*.test.ts` / `test_*.py`
- Django tests: use `APITestCase` from DRF, fixtures for test data
- Frontend tests: use vitest + @testing-library/react
- E2E: Playwright (configured via MCP server)
- data-testid on interactive elements for E2E targeting
