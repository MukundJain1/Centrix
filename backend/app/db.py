from collections.abc import AsyncIterator
from uuid import uuid4

from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from .config import settings


class Base(DeclarativeBase):
    pass


def normalize_database_url(url: str) -> str:
    """Accept the plain URL Supabase shows (postgresql://...) and make it async."""
    if url.startswith("postgres://"):
        return "postgresql+asyncpg://" + url[len("postgres://"):]
    if url.startswith("postgresql://"):
        return "postgresql+asyncpg://" + url[len("postgresql://"):]
    return url


def build_engine(url: str) -> AsyncEngine:
    url = normalize_database_url(url)
    kwargs: dict = {"pool_pre_ping": True}
    if url.startswith("postgresql+asyncpg"):
        # Safe with Supabase's pooler (pgbouncer-style) connections.
        kwargs["connect_args"] = {
            "statement_cache_size": 0,
            "prepared_statement_cache_size": 0,
            "prepared_statement_name_func": lambda: f"__asyncpg_{uuid4().hex}__",
        }
    return create_async_engine(url, **kwargs)


engine = build_engine(settings.database_url)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False)


async def get_session() -> AsyncIterator[AsyncSession]:
    async with SessionLocal() as session:
        yield session
