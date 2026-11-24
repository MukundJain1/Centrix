"""Tests run on in-memory SQLite by default.

To run them against a real Postgres built from supabase/schema.sql:

    TEST_DATABASE_URL=postgresql://user:pass@localhost/dbname \
    TEST_USE_SCHEMA_SQL=1 pytest
"""
import os
from pathlib import Path

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import async_sessionmaker
from sqlalchemy.pool import StaticPool

os.environ.setdefault("ENV", "dev")

from app import models  # noqa: E402,F401
from app.config import settings  # noqa: E402
from app.db import Base, build_engine, get_session  # noqa: E402
from app.main import app  # noqa: E402

TEST_URL = os.environ.get("TEST_DATABASE_URL", "sqlite+aiosqlite:///:memory:")
SCHEMA_SQL = Path(__file__).resolve().parent.parent / "supabase" / "schema.sql"
TABLES = "baseline_items, baseline_categories, refresh_tokens, otp_challenges, user_profiles, users"


@pytest_asyncio.fixture
async def engine():
    if TEST_URL.startswith("sqlite"):
        from sqlalchemy.ext.asyncio import create_async_engine

        eng = create_async_engine(TEST_URL, poolclass=StaticPool, connect_args={"check_same_thread": False})
        async with eng.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        yield eng
    else:
        eng = build_engine(TEST_URL)
        async with eng.begin() as conn:
            await conn.execute(text(f"drop table if exists {TABLES} cascade"))
            if os.environ.get("TEST_USE_SCHEMA_SQL"):
                raw = await conn.get_raw_connection()
                await raw.driver_connection.execute(SCHEMA_SQL.read_text(encoding="utf-8"))
            else:
                await conn.run_sync(Base.metadata.create_all)
        yield eng
    await eng.dispose()


@pytest_asyncio.fixture
async def client(engine):
    maker = async_sessionmaker(engine, expire_on_commit=False)

    async def override():
        async with maker() as session:
            yield session

    app.dependency_overrides[get_session] = override
    settings.otp_resend_seconds = 0  # let tests ask for codes back to back
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()


PHONE = {"dial_code": "+91", "phone": "98765 43210", "country_iso": "IN"}


async def register_user(client, pin="4829", phone=None):
    """Runs the whole OTP + register flow. Returns the AuthOut JSON."""
    phone = phone or PHONE
    sent = await client.post("/v1/auth/otp/send", json=phone)
    assert sent.status_code == 200, sent.text
    verified = await client.post("/v1/auth/otp/verify", json={**phone, "code": sent.json()["dev_hint"]})
    assert verified.status_code == 200, verified.text
    registered = await client.post(
        "/v1/auth/register",
        json={"registration_token": verified.json()["registration_token"], "pin": pin},
    )
    assert registered.status_code == 201, registered.text
    return registered.json()


def bearer(auth):
    return {"Authorization": f"Bearer {auth['access_token']}"}
