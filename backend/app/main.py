from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from sqlalchemy import text

from .config import settings
from .db import Base, engine
from .errors import ApiError, api_error_handler, validation_error_handler
from .routers import auth, baseline


@asynccontextmanager
async def lifespan(_: FastAPI):
    settings.check_production_ready()
    if settings.auto_create_tables:
        # Handy for local SQLite. On Supabase run supabase/schema.sql instead.
        import app.models  # noqa: F401  (registers the tables)

        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()


app = FastAPI(title="Daily Expense API", version="0.1.0", lifespan=lifespan)
app.add_exception_handler(ApiError, api_error_handler)
app.add_exception_handler(RequestValidationError, validation_error_handler)

app.include_router(auth.router)
app.include_router(baseline.router)


@app.get("/health", tags=["meta"])
async def health():
    """Cheap check. Point an uptime pinger here to keep a free server awake."""
    return {"status": "ok"}


@app.get("/health/db", tags=["meta"])
async def health_db():
    async with engine.connect() as conn:
        await conn.execute(text("select 1"))
    return {"status": "ok", "database": "reachable"}
