# Check Project Health

```bash
echo "=== Plane Project Health ==="
echo ""

echo "--- Git Status ---"
git status --short
echo ""

echo "--- Recent Commits ---"
git log --oneline -5
echo ""

echo "--- Docker Services ---"
docker compose ps 2>/dev/null || echo "Docker not running"
echo ""

echo "--- Frontend Lint ---"
pnpm check:lint 2>&1 | tail -3
echo ""

echo "--- TypeScript ---"
pnpm check:types 2>&1 | tail -3
echo ""

echo "--- Python Lint ---"
cd apps/api && python -m ruff check . 2>&1 | tail -3 && cd ../..
echo ""

echo "--- Django Migrations ---"
cd apps/api && python manage.py showmigrations --plan 2>/dev/null | grep '\[ \]' | wc -l && cd ../..
echo "unapplied migrations"

echo ""
echo "=== Done ==="
```
