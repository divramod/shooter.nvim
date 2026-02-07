# FastAPI Conventions

FastAPI-specific coding standards and best practices.

## Request/Response Models

- Use Pydantic models for all request and response validation
- Define separate models for create, update, and response schemas
- Use `Field()` for validation constraints and descriptions
- Keep models in a `schemas.py` or `models/` directory
- Use `model_config` with `from_attributes = True` for ORM integration

## Endpoints

- Use async endpoints for I/O-bound operations (database, HTTP, file)
- Use sync endpoints for CPU-bound operations
- Return proper HTTP status codes:
  - `201` for created resources
  - `204` for successful deletions
  - `404` for not found
  - `422` for validation errors (automatic with Pydantic)
- Use `status_code` parameter: `@app.post("/items", status_code=201)`

## Dependency Injection

- Use `Depends()` for shared logic: database sessions, auth, config
- Create reusable dependencies as functions or classes
- Use `yield` dependencies for setup/teardown (database connections)
- Chain dependencies — they compose naturally

## Route Organization

- Use `APIRouter` for route grouping by domain
- Prefix routers: `router = APIRouter(prefix="/users", tags=["users"])`
- Keep route handlers thin — delegate business logic to service functions
- Use `include_router` in the main app

## Error Handling

- Use `HTTPException` for HTTP errors with clear detail messages
- Create custom exception handlers for domain-specific errors
- Never expose internal errors or stack traces to clients
- Use structured error responses with consistent format

## Documentation

- Write docstrings on endpoints — they become OpenAPI descriptions
- Use `summary` and `description` parameters on routes
- Use `response_model` to document and filter response shapes
- Use `tags` for logical grouping in Swagger UI

## Background Tasks

- Use `BackgroundTasks` for non-blocking operations (emails, notifications)
- For heavy background work, use Celery or task queues instead
- Always handle failures in background tasks gracefully

## Database

- Use SQLAlchemy 2.0 async or Tortoise ORM for async database access
- Create database sessions via dependency injection
- Use Alembic for migrations
- Never run migrations automatically on startup in production

## Testing

- Use `TestClient` for synchronous endpoint testing
- Use `httpx.AsyncClient` for async endpoint testing
- Override dependencies in tests: `app.dependency_overrides[get_db] = mock_db`
- Test validation by sending invalid data and asserting 422 responses

## Security

- Use `OAuth2PasswordBearer` or API key schemes for auth
- Validate JWT tokens in dependencies
- Use CORS middleware with specific origins
- Rate limit public endpoints
