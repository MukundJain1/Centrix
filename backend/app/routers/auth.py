import math
import uuid
from datetime import timedelta

from fastapi import APIRouter, Depends, Response
from fastapi.concurrency import run_in_threadpool
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import settings
from ..db import get_session
from ..deps import current_profile, current_user
from ..errors import ApiError
from ..models import OtpChallenge, RefreshToken, User, UserProfile
from ..otp import get_otp_sender
from ..phone import normalize_phone
from ..schemas import (
    AuthOut,
    LoginIn,
    MeOut,
    OtpSentOut,
    OtpVerifyIn,
    PhoneIn,
    ProfileUpdateIn,
    RefreshIn,
    RegisterIn,
    RegistrationTokenOut,
)
from ..security import (
    burn_time,
    create_token,
    decode_token,
    hash_otp,
    hash_pin,
    hash_refresh_token,
    is_weak_pin,
    make_otp_code,
    otp_matches,
    verify_pin,
)
from ..services import build_me, issue_tokens
from ..timeutil import as_utc, utcnow
from ..schemas import (PinVerifyIn, PinVerifyOut)

router = APIRouter(prefix="/v1/auth", tags=["auth"])


def _seconds_left(until) -> int:
    return max(1, math.ceil((as_utc(until) - utcnow()).total_seconds()))


def _clean_text(value: str | None) -> str | None:
    if value is None:
        return None
    trimmed = value.strip()
    return trimmed if trimmed else None


# ------------------------------------------------------------ OTP: send

@router.post("/otp/send", response_model=OtpSentOut)
async def send_otp(body: PhoneIn, session: AsyncSession = Depends(get_session)):
    """Step 1 of registering: text a one-time code to the number."""
    phone = normalize_phone(body.dial_code, body.phone, body.country_iso)
    now = utcnow()

    if await session.scalar(select(User.id).where(User.phone_e164 == phone)):
        raise ApiError(409, "PHONE_EXISTS", "This number is already registered. Please sign in.")

    latest = await session.scalar(
        select(OtpChallenge)
        .where(OtpChallenge.phone_e164 == phone)
        .order_by(OtpChallenge.created_at.desc())
        .limit(1)
    )
    if latest is not None:
        wait = settings.otp_resend_seconds - (now - as_utc(latest.created_at)).total_seconds()
        if wait > 0:
            retry = math.ceil(wait)
            raise ApiError(429, "OTP_COOLDOWN", f"Please wait {retry}s before asking for another code.", retry_after=retry)

    # Protects you from SMS-pumping abuse (every SMS costs money).
    sent_last_hour = await session.scalar(
        select(func.count())
        .select_from(OtpChallenge)
        .where(OtpChallenge.phone_e164 == phone, OtpChallenge.created_at > now - timedelta(hours=1))
    )
    if (sent_last_hour or 0) >= settings.otp_max_per_hour:
        raise ApiError(429, "OTP_LIMIT", "Too many codes requested. Try again in an hour.", retry_after=3600)

    code = make_otp_code()
    challenge_id = uuid.uuid4()
    session.add(
        OtpChallenge(
            id=challenge_id,
            phone_e164=phone,
            country_iso=body.country_iso.upper(),
            code_hash=hash_otp(str(challenge_id), code),
            expires_at=now + timedelta(minutes=settings.otp_ttl_minutes),
        )
    )
    await session.flush()

    try:
        await get_otp_sender().send(phone, code)
    except ApiError:
        raise
    except Exception:
        raise ApiError(502, "OTP_SEND_FAILED", "Could not send the code. Please try again.")

    await session.commit()
    return OtpSentOut(
        expires_in=settings.otp_ttl_minutes * 60,
        resend_in=settings.otp_resend_seconds,
        dev_hint=code if settings.is_dev else None,
    )


# ----------------------------------------------------------- OTP: verify

@router.post("/otp/verify", response_model=RegistrationTokenOut)
async def verify_otp(body: OtpVerifyIn, session: AsyncSession = Depends(get_session)):
    """Step 2: check the code. Returns a short-lived token for step 3."""
    phone = normalize_phone(body.dial_code, body.phone, body.country_iso)
    now = utcnow()

    challenge = await session.scalar(
        select(OtpChallenge)
        .where(OtpChallenge.phone_e164 == phone, OtpChallenge.consumed_at.is_(None))
        .order_by(OtpChallenge.created_at.desc())
        .limit(1)
    )
    if challenge is None or as_utc(challenge.expires_at) < now:
        raise ApiError(400, "OTP_EXPIRED", "That code has expired. Please request a new one.")
    if challenge.attempts >= settings.otp_max_attempts:
        raise ApiError(429, "OTP_LOCKED", "Too many wrong codes. Please request a new one.")

    if not otp_matches(str(challenge.id), body.code, challenge.code_hash):
        challenge.attempts += 1
        left = settings.otp_max_attempts - challenge.attempts
        await session.commit()
        raise ApiError(400, "WRONG_OTP", "That code is not right.", attempts_left=left)

    if challenge.verified_at is None:
        challenge.verified_at = now
        await session.commit()

    minutes = settings.registration_token_minutes
    return RegistrationTokenOut(
        registration_token=create_token(str(challenge.id), "register", minutes),
        expires_in=minutes * 60,
    )


# --------------------------------------------------------------- register

@router.post("/register", response_model=AuthOut, status_code=201)
async def register(body: RegisterIn, session: AsyncSession = Depends(get_session)):
    """Step 3: choose a PIN. Creates the account and signs the user in."""
    claims = decode_token(body.registration_token, "register", "INVALID_REGISTRATION")
    challenge = await session.get(OtpChallenge, uuid.UUID(claims["sub"]))
    if challenge is None or challenge.verified_at is None or challenge.consumed_at is not None:
        raise ApiError(400, "INVALID_REGISTRATION", "Please verify your number again.")

    if is_weak_pin(body.pin):
        raise ApiError(422, "WEAK_PIN", "That PIN is too easy to guess. Pick a less obvious one.")

    phone = challenge.phone_e164
    if await session.scalar(select(User.id).where(User.phone_e164 == phone)):
        raise ApiError(409, "PHONE_EXISTS", "This number is already registered. Please sign in.")

    user_id = uuid.uuid4()
    pin_hash = await run_in_threadpool(hash_pin, body.pin, str(user_id))
    user = User(id=user_id, phone_e164=phone, country_iso=challenge.country_iso, pin_hash=pin_hash)
    profile = UserProfile(user_id=user_id)
    session.add(user)
    await session.flush()
    session.add(profile)
    await session.flush()  # fills in column defaults (currency ...) before we read them
    challenge.consumed_at = utcnow()

    try:
        auth = await issue_tokens(session, user, profile, body.device_label)
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise ApiError(409, "PHONE_EXISTS", "This number is already registered. Please sign in.")
    return auth


# ------------------------------------------------------------------ login

@router.post("/login", response_model=AuthOut)
async def login(body: LoginIn, session: AsyncSession = Depends(get_session)):
    """Phone + PIN. The server decides whether the PIN is right."""
    phone = normalize_phone(body.dial_code, body.phone, body.country_iso)
    now = utcnow()
    user = await session.scalar(select(User).where(User.phone_e164 == phone))

    if user is None:
        # Same response and similar timing as a wrong PIN.
        await run_in_threadpool(burn_time)
        raise ApiError(401, "WRONG_PIN", "Wrong PIN.", attempts_left=settings.pin_max_attempts - 1)

    if user.locked_until is not None and as_utc(user.locked_until) > now:
        retry = _seconds_left(user.locked_until)
        raise ApiError(
            423, "PIN_LOCKED",
            f"Too many wrong attempts. Try again in {math.ceil(retry / 60)} min.",
            retry_after=retry,
        )

    ok = await run_in_threadpool(verify_pin, body.pin, str(user.id), user.pin_hash)
    if not ok:
        user.failed_pin_attempts += 1
        if user.failed_pin_attempts >= settings.pin_max_attempts:
            user.failed_pin_attempts = 0
            user.locked_until = now + timedelta(minutes=settings.pin_lock_minutes)
            await session.commit()
            raise ApiError(
                423, "PIN_LOCKED",
                f"Too many wrong attempts. Try again in {settings.pin_lock_minutes} min.",
                retry_after=settings.pin_lock_minutes * 60,
            )
        left = settings.pin_max_attempts - user.failed_pin_attempts
        await session.commit()
        raise ApiError(401, "WRONG_PIN", "Wrong PIN.", attempts_left=left)

    user.failed_pin_attempts = 0
    user.locked_until = None
    profile = await session.get(UserProfile, user.id)
    if profile is None:
        profile = UserProfile(user_id=user.id)
        session.add(profile)
        await session.flush()
    auth = await issue_tokens(session, user, profile, body.device_label)
    await session.commit()
    return auth


# ---------------------------------------------------------------- refresh

@router.post("/refresh", response_model=AuthOut)
async def refresh(body: RefreshIn, session: AsyncSession = Depends(get_session)):
    """Swap a refresh token for a new pair. Each refresh token works once."""
    now = utcnow()
    token = await session.scalar(
        select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(body.refresh_token))
    )
    if token is None or as_utc(token.expires_at) < now:
        raise ApiError(401, "INVALID_REFRESH", "Please sign in again.")

    if token.revoked_at is not None:
        # A used token came back: it may have been stolen. Sign out everywhere.
        await session.execute(
            update(RefreshToken)
            .where(RefreshToken.user_id == token.user_id, RefreshToken.revoked_at.is_(None))
            .values(revoked_at=now)
        )
        await session.commit()
        raise ApiError(401, "INVALID_REFRESH", "Please sign in again.")

    user = await session.get(User, token.user_id)
    profile = await session.get(UserProfile, token.user_id)
    if user is None or profile is None:
        raise ApiError(401, "INVALID_REFRESH", "Please sign in again.")

    token.revoked_at = now
    auth = await issue_tokens(session, user, profile, token.device_label)
    await session.commit()
    return auth


# ----------------------------------------------------------------- logout

@router.post("/logout", status_code=204)
async def logout(body: RefreshIn, session: AsyncSession = Depends(get_session)):
    token = await session.scalar(
        select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(body.refresh_token))
    )
    if token is not None and token.revoked_at is None:
        token.revoked_at = utcnow()
        await session.commit()
    return Response(status_code=204)


# --------------------------------------------------------------------- me

@router.get("/me", response_model=MeOut)
async def me(user: User = Depends(current_user), profile: UserProfile = Depends(current_profile)):
    """Who am I, and which setup steps are left?"""
    return build_me(user, profile)


@router.put("/me", response_model=MeOut)
async def update_me(
    body: ProfileUpdateIn,
    user: User = Depends(current_user),
    profile: UserProfile = Depends(current_profile),
    session: AsyncSession = Depends(get_session),
):
    """Update editable user profile details."""
    profile.full_name = _clean_text(body.full_name)
    profile.age = body.age
    profile.date_of_birth = body.date_of_birth
    profile.gender = _clean_text(body.gender)
    profile.occupation = _clean_text(body.occupation)
    await session.commit()
    return build_me(user, profile)

@router.post("/verify-pin", response_model=PinVerifyOut)
async def check_pin(
    body: PinVerifyIn,
    user: User = Depends(current_user),
    session: AsyncSession = Depends(get_session),
):
    """Verify the signed-in user's PIN before sensitive actions."""
    now = utcnow()
    if user.locked_until is not None and as_utc(user.locked_until) > now:
        retry = _seconds_left(user.locked_until)
        raise ApiError(
            423,
            "PIN_LOCKED",
            f"Too many wrong attempts. Try again in {math.ceil(retry / 60)} min.",
            retry_after=retry,
        )

    ok = await run_in_threadpool(verify_pin, body.pin, str(user.id), user.pin_hash)
    if not ok:
        user.failed_pin_attempts += 1
        if user.failed_pin_attempts >= settings.pin_max_attempts:
            user.failed_pin_attempts = 0
            user.locked_until = now + timedelta(minutes=settings.pin_lock_minutes)
            await session.commit()
            raise ApiError(
                423,
                "PIN_LOCKED",
                f"Too many wrong attempts. Try again in {settings.pin_lock_minutes} min.",
                retry_after=settings.pin_lock_minutes * 60,
            )
        left = settings.pin_max_attempts - user.failed_pin_attempts
        await session.commit()
        raise ApiError(401, "WRONG_PIN", "Wrong PIN.", attempts_left=left)

    user.failed_pin_attempts = 0
    user.locked_until = None
    await session.commit()
    return PinVerifyOut(verified=True)