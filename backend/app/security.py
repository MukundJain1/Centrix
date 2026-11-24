import hashlib
import hmac
import secrets
from datetime import timedelta

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError

from .config import settings
from .errors import ApiError
from .timeutil import utcnow

_ph = PasswordHasher()  # argon2id with sensible defaults


# --------------------------------------------------------------------- PIN
#
# A 4-digit PIN has only 10,000 possibilities, so anyone who steals the
# database could crack the hashes in seconds, whatever algorithm is used.
# To prevent that, the PIN is first run through HMAC with a secret "pepper"
# that lives in the server's environment, NOT in the database. A leaked
# database alone is then useless. Wrong-PIN lockout (see routers/auth.py)
# protects against guessing through the API.

def _peppered(pin: str, user_key: str) -> str:
    return hmac.new(
        settings.pin_pepper.encode(), f"{user_key}:{pin}".encode(), hashlib.sha256
    ).hexdigest()


def hash_pin(pin: str, user_key: str) -> str:
    return _ph.hash(_peppered(pin, user_key))


def verify_pin(pin: str, user_key: str, stored_hash: str) -> bool:
    try:
        return _ph.verify(stored_hash, _peppered(pin, user_key))
    except (VerifyMismatchError, InvalidHashError):
        return False


_DUMMY_HASH = _ph.hash("dummy")


def burn_time() -> None:
    """Do the same work as a real check, so unknown phone numbers are not
    distinguishable from wrong PINs by response time."""
    try:
        _ph.verify(_DUMMY_HASH, "not-the-pin")
    except (VerifyMismatchError, InvalidHashError):
        pass


WEAK_PINS = {
    "0000", "1111", "2222", "3333", "4444", "5555", "6666", "7777", "8888", "9999",
    "1234", "4321", "2345", "3456", "4567", "5678", "6789", "0123", "1212", "2580",
    "000000", "111111", "123456", "654321",
}


def is_weak_pin(pin: str) -> bool:
    return pin in WEAK_PINS


# --------------------------------------------------------------------- OTP

def make_otp_code() -> str:
    if settings.is_dev:
        return settings.dev_fixed_otp
    return f"{secrets.randbelow(10**6):06d}"


def hash_otp(challenge_id: str, code: str) -> str:
    return hmac.new(
        settings.pin_pepper.encode(), f"otp:{challenge_id}:{code}".encode(), hashlib.sha256
    ).hexdigest()


def otp_matches(challenge_id: str, code: str, stored_hash: str) -> bool:
    return hmac.compare_digest(hash_otp(challenge_id, code), stored_hash)


# ------------------------------------------------------------------ tokens

def create_token(subject: str, typ: str, minutes: int) -> str:
    now = utcnow()
    payload = {"sub": subject, "typ": typ, "iat": now, "exp": now + timedelta(minutes=minutes)}
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def decode_token(token: str, typ: str, error_code: str = "INVALID_TOKEN") -> dict:
    try:
        claims = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        raise ApiError(401, "TOKEN_EXPIRED" if typ == "access" else error_code, "Your session expired.")
    except jwt.PyJWTError:
        raise ApiError(401, error_code, "Invalid token.")
    if claims.get("typ") != typ:
        raise ApiError(401, error_code, "Invalid token.")
    return claims


def new_refresh_token() -> tuple[str, str]:
    """Returns (token to give the app, hash to store in the database)."""
    token = secrets.token_urlsafe(48)
    return token, hash_refresh_token(token)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()
