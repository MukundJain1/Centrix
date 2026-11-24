from datetime import timedelta

from sqlalchemy import select, update

from app.config import settings
from app.models import OtpChallenge, User
from app.timeutil import utcnow

from .conftest import PHONE, bearer, register_user


async def test_register_then_login(client):
    auth = await register_user(client, pin="4829")
    assert auth["user"]["phone"] == "+919876543210"
    assert auth["user"]["onboarding"] == {"baseline_done": False, "cycle_done": False}

    login = await client.post("/v1/auth/login", json={**PHONE, "pin": "4829"})
    assert login.status_code == 200
    me = await client.get("/v1/auth/me", headers=bearer(login.json()))
    assert me.status_code == 200
    assert me.json()["phone"] == "+919876543210"


async def test_wrong_pin_counts_down_then_locks(client):
    await register_user(client, pin="4829")

    for expected_left in (4, 3, 2, 1):
        r = await client.post("/v1/auth/login", json={**PHONE, "pin": "9999"})
        assert r.status_code == 401
        assert r.json()["error"]["code"] == "WRONG_PIN"
        assert r.json()["error"]["attempts_left"] == expected_left

    fifth = await client.post("/v1/auth/login", json={**PHONE, "pin": "9999"})
    assert fifth.status_code == 423
    assert fifth.json()["error"]["code"] == "PIN_LOCKED"
    assert fifth.json()["error"]["retry_after"] == settings.pin_lock_minutes * 60

    # Even the right PIN is refused while locked.
    right = await client.post("/v1/auth/login", json={**PHONE, "pin": "4829"})
    assert right.status_code == 423


async def test_correct_pin_resets_the_counter(client):
    await register_user(client, pin="4829")
    await client.post("/v1/auth/login", json={**PHONE, "pin": "9999"})
    await client.post("/v1/auth/login", json={**PHONE, "pin": "9999"})
    ok = await client.post("/v1/auth/login", json={**PHONE, "pin": "4829"})
    assert ok.status_code == 200
    again = await client.post("/v1/auth/login", json={**PHONE, "pin": "9999"})
    assert again.json()["error"]["attempts_left"] == 4


async def test_unknown_phone_looks_like_wrong_pin(client):
    r = await client.post("/v1/auth/login", json={**PHONE, "pin": "4829"})
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "WRONG_PIN"


async def test_lock_expires(client, engine):
    await register_user(client, pin="4829")
    for _ in range(5):
        await client.post("/v1/auth/login", json={**PHONE, "pin": "9999"})

    from sqlalchemy.ext.asyncio import async_sessionmaker

    maker = async_sessionmaker(engine, expire_on_commit=False)
    async with maker() as s:
        await s.execute(update(User).values(locked_until=utcnow() - timedelta(seconds=1)))
        await s.commit()

    ok = await client.post("/v1/auth/login", json={**PHONE, "pin": "4829"})
    assert ok.status_code == 200


async def test_cannot_register_the_same_phone_twice(client):
    await register_user(client)
    again = await client.post("/v1/auth/otp/send", json=PHONE)
    assert again.status_code == 409
    assert again.json()["error"]["code"] == "PHONE_EXISTS"


async def test_wrong_otp_then_locked(client):
    await client.post("/v1/auth/otp/send", json=PHONE)
    for left in (4, 3, 2, 1, 0):
        r = await client.post("/v1/auth/otp/verify", json={**PHONE, "code": "000000"})
        assert r.status_code == 400
        assert r.json()["error"] == {"code": "WRONG_OTP", "message": "That code is not right.", "attempts_left": left}
    locked = await client.post("/v1/auth/otp/verify", json={**PHONE, "code": "123456"})
    assert locked.status_code == 429
    assert locked.json()["error"]["code"] == "OTP_LOCKED"


async def test_expired_otp(client, engine):
    await client.post("/v1/auth/otp/send", json=PHONE)
    from sqlalchemy.ext.asyncio import async_sessionmaker

    maker = async_sessionmaker(engine, expire_on_commit=False)
    async with maker() as s:
        await s.execute(update(OtpChallenge).values(expires_at=utcnow() - timedelta(seconds=1)))
        await s.commit()
    r = await client.post("/v1/auth/otp/verify", json={**PHONE, "code": "123456"})
    assert r.status_code == 400
    assert r.json()["error"]["code"] == "OTP_EXPIRED"


async def test_otp_resend_cooldown(client):
    settings.otp_resend_seconds = 30
    try:
        first = await client.post("/v1/auth/otp/send", json=PHONE)
        assert first.status_code == 200
        second = await client.post("/v1/auth/otp/send", json=PHONE)
        assert second.status_code == 429
        assert second.json()["error"]["code"] == "OTP_COOLDOWN"
        assert 1 <= second.json()["error"]["retry_after"] <= 30
    finally:
        settings.otp_resend_seconds = 0


async def test_otp_hourly_cap(client):
    for _ in range(settings.otp_max_per_hour):
        assert (await client.post("/v1/auth/otp/send", json=PHONE)).status_code == 200
    capped = await client.post("/v1/auth/otp/send", json=PHONE)
    assert capped.status_code == 429
    assert capped.json()["error"]["code"] == "OTP_LIMIT"


async def test_registration_token_works_once(client):
    sent = await client.post("/v1/auth/otp/send", json=PHONE)
    token = (
        await client.post("/v1/auth/otp/verify", json={**PHONE, "code": sent.json()["dev_hint"]})
    ).json()["registration_token"]
    first = await client.post("/v1/auth/register", json={"registration_token": token, "pin": "4829"})
    assert first.status_code == 201
    second = await client.post("/v1/auth/register", json={"registration_token": token, "pin": "4829"})
    assert second.status_code == 400
    assert second.json()["error"]["code"] == "INVALID_REGISTRATION"


async def test_register_needs_a_verified_token(client):
    r = await client.post("/v1/auth/register", json={"registration_token": "nonsense", "pin": "4829"})
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "INVALID_REGISTRATION"


async def test_weak_pin_is_rejected(client):
    sent = await client.post("/v1/auth/otp/send", json=PHONE)
    token = (
        await client.post("/v1/auth/otp/verify", json={**PHONE, "code": sent.json()["dev_hint"]})
    ).json()["registration_token"]
    r = await client.post("/v1/auth/register", json={"registration_token": token, "pin": "1234"})
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "WEAK_PIN"
    # The token is still usable with a better PIN.
    ok = await client.post("/v1/auth/register", json={"registration_token": token, "pin": "4829"})
    assert ok.status_code == 201


async def test_pin_is_not_stored_in_plain_text(client, engine):
    await register_user(client, pin="4829")
    from sqlalchemy.ext.asyncio import async_sessionmaker

    maker = async_sessionmaker(engine, expire_on_commit=False)
    async with maker() as s:
        stored = (await s.scalars(select(User.pin_hash))).one()
    assert "4829" not in stored
    assert stored.startswith("$argon2id$")


async def test_invalid_phone_and_validation_errors(client):
    bad = await client.post("/v1/auth/otp/send", json={**PHONE, "phone": "12345"})
    assert bad.status_code == 422
    assert bad.json()["error"]["code"] == "INVALID_PHONE"

    malformed = await client.post("/v1/auth/login", json={**PHONE, "pin": "12ab"})
    assert malformed.status_code == 422
    assert malformed.json()["error"]["code"] == "VALIDATION_ERROR"


async def test_other_country_numbers(client):
    us = {"dial_code": "+1", "phone": "(415) 555-2671", "country_iso": "US"}
    auth = await register_user(client, phone=us)
    assert auth["user"]["phone"] == "+14155552671"


async def test_refresh_rotates_and_detects_reuse(client):
    auth = await register_user(client)
    first = await client.post("/v1/auth/refresh", json={"refresh_token": auth["refresh_token"]})
    assert first.status_code == 200
    new = first.json()
    assert new["refresh_token"] != auth["refresh_token"]

    # The old token was already used: refuse it and sign out every device.
    reuse = await client.post("/v1/auth/refresh", json={"refresh_token": auth["refresh_token"]})
    assert reuse.status_code == 401
    assert reuse.json()["error"]["code"] == "INVALID_REFRESH"
    after = await client.post("/v1/auth/refresh", json={"refresh_token": new["refresh_token"]})
    assert after.status_code == 401


async def test_logout_revokes_the_refresh_token(client):
    auth = await register_user(client)
    out = await client.post("/v1/auth/logout", json={"refresh_token": auth["refresh_token"]})
    assert out.status_code == 204
    r = await client.post("/v1/auth/refresh", json={"refresh_token": auth["refresh_token"]})
    assert r.status_code == 401


async def test_protected_routes_need_a_token(client):
    for method, url in (("GET", "/v1/auth/me"), ("GET", "/v1/baseline"), ("PUT", "/v1/cycle")):
        r = await client.request(method, url)
        assert r.status_code == 401
        assert r.json()["error"]["code"] == "UNAUTHORIZED"

    bad = await client.get("/v1/auth/me", headers={"Authorization": "Bearer nope"})
    assert bad.status_code == 401
