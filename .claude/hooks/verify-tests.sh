#!/bin/bash
# Pre-stop verification: ensure quality before ending session
set -e
echo "Running pre-stop verification..."

# 1. Frontend lint check (fast)
echo "  OxLint check..."
pnpm check:lint 2>/dev/null || { echo "Lint errors found!"; exit 1; }

# 2. TypeScript type check
echo "  TypeScript check..."
pnpm check:types 2>/dev/null || { echo "TypeScript errors found!"; exit 1; }

# 3. Python lint (if changed)
if git diff --cached --name-only | grep -q '\.py$'; then
  echo "  Python lint check..."
  cd apps/api && python -m ruff check . 2>/dev/null || { echo "Python lint errors found!"; exit 1; }
  cd ../..
fi

# 4. Python tests (if backend changed)
if git diff --cached --name-only | grep -q 'apps/api/'; then
  echo "  Python tests..."
  cd apps/api && python -m pytest --tb=short -q 2>/dev/null || { echo "Python tests failed!"; exit 1; }
  cd ../..
fi

# 5. Uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
  echo "Uncommitted changes detected. Commit and push before ending."
  exit 1
fi

# 6. Unpushed commits
UNPUSHED=$(git log --oneline origin/preview..HEAD 2>/dev/null | wc -l)
if [[ "$UNPUSHED" -gt 0 ]]; then
  echo "$UNPUSHED unpushed commit(s). Push before ending."
  exit 1
fi

echo "All checks passed. Safe to end session."
