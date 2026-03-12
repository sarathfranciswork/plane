# Start Development Environment

```bash
echo "=== Starting Infrastructure ==="
docker compose -f docker-compose-local.yml up -d

echo ""
echo "=== Waiting for PostgreSQL ==="
until docker compose -f docker-compose-local.yml exec plane-db pg_isready 2>/dev/null; do sleep 1; done
echo "PostgreSQL ready."

echo ""
echo "=== Running Migrations ==="
cd apps/api && python manage.py migrate && cd ../..

echo ""
echo "=== Starting Dev Servers ==="
echo "Run: pnpm dev"
echo "  web:   http://localhost:3000"
echo "  admin: http://localhost:3001"
echo "  space: http://localhost:3002"
echo "  api:   http://localhost:8000"
```
