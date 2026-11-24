import uuid

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from .db import get_session
from .errors import ApiError
from .models import User, UserProfile
from .security import decode_token

_bearer = HTTPBearer(auto_error=False)


async def current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    session: AsyncSession = Depends(get_session),
) -> User:
    if creds is None:
        raise ApiError(401, "UNAUTHORIZED", "Please sign in.")
    claims = decode_token(creds.credentials, "access", "UNAUTHORIZED")
    user = await session.get(User, uuid.UUID(claims["sub"]))
    if user is None:
        raise ApiError(401, "UNAUTHORIZED", "Please sign in.")
    return user


async def current_profile(
    user: User = Depends(current_user),
    session: AsyncSession = Depends(get_session),
) -> UserProfile:
    profile = await session.get(UserProfile, user.id)
    if profile is None:  # should not happen; create lazily to be safe
        profile = UserProfile(user_id=user.id)
        session.add(profile)
        await session.flush()
    return profile
