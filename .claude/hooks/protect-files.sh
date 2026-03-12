#!/bin/bash
# Prevent accidental modification of critical files
PROTECTED_FILES=(
  "pnpm-lock.yaml"
  ".claude/settings.json"
  "CLAUDE.md"
  ".env"
  ".env.example"
  "apps/api/.env"
  "apps/api/.env.example"
  "apps/web/.env"
  "apps/web/.env.example"
  "turbo.json"
)

CHANGED="$1"
for f in "${PROTECTED_FILES[@]}"; do
  if [[ "$CHANGED" == *"$f" ]]; then
    echo "PROTECTED FILE: $f — Are you sure you want to modify this? Use --force flag if intentional."
    exit 1
  fi
done
exit 0
