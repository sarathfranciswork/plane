# Run All Tests

```bash
echo "=== Frontend Lint ==="
pnpm check:lint

echo ""
echo "=== TypeScript Check ==="
pnpm check:types

echo ""
echo "=== Frontend Format ==="
pnpm check:format

echo ""
echo "=== Python Lint ==="
cd apps/api && python -m ruff check . && cd ../..

echo ""
echo "=== Python Tests ==="
cd apps/api && python -m pytest --tb=short -q && cd ../..

echo ""
echo "=== Frontend Build ==="
pnpm build

echo ""
echo "=== All Done ==="
```
