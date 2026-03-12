# Git Rules

- Commit messages follow conventional commits: `feat:`, `fix:`, `refactor:`, `test:`, `chore:`, `docs:`
- Include scope: `feat(web):`, `fix(api):`, `chore(deps):`
- Never commit `.env` files, credentials, or secrets
- Never commit `node_modules/`, `__pycache__/`, or build artifacts
- Run checks before committing
- Push after every commit -- no dangling local commits
- One logical change per commit
- Main branch is `preview` -- always base work off `preview`
