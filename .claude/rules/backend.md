# Backend Rules (apps/api/**)

- Django 4.2 + DRF -- class-based views extending `BaseViewSet` or `BaseAPIView`
- View -> Serializer -> Model pattern
- Ruff for linting, 120 char line length, 4-space indentation
- All API endpoints must have proper permission classes (WorkspacePermission, ProjectPermission)
- NEVER expose raw errors to client -- use proper DRF exception handling
- NEVER import from apps/web or packages/ -- backend is standalone Python
- Use Django ORM -- no raw SQL unless absolutely necessary
- Transactions for multi-table writes
- Celery tasks for anything async (emails, webhooks, cleanup)
- Log with structured JSON logger (python-json-logger), not print()
- All model changes require Django migrations: `python manage.py makemigrations`
- Soft deletion pattern -- use `SoftDeletionManager`, never hard-delete directly
- Rate limit all public endpoints via DRF throttling
- Validate all input with DRF serializers
- Follow existing URL patterns: `/api/workspaces/<slug>/projects/<pk>/...`
