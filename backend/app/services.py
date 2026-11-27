from datetime import timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from .config import settings
from .models import RefreshToken, User, UserProfile
from .schemas import AuthOut, MeOut, OnboardingOut
from .security import create_token, new_refresh_token
from .timeutil import utcnow


def build_me(user: User, profile: UserProfile) -> MeOut:
    return MeOut(
        id=str(user.id),
        phone=user.phone_e164,
        country_iso=user.country_iso,
        full_name=profile.full_name,
        age=profile.age,
        date_of_birth=profile.date_of_birth,
        gender=profile.gender,
        occupation=profile.occupation,
        currency=profile.currency,
        monthly_surplus=float(profile.monthly_surplus) if profile.monthly_surplus is not None else None,
        daily_limit=float(profile.daily_limit) if profile.daily_limit is not None else None,
        payday=profile.payday,
        created_at=user.created_at,
        onboarding=OnboardingOut(
            baseline_done=profile.baseline_completed_at is not None,
            cycle_done=profile.cycle_completed_at is not None,
        ),
    )

async def issue_tokens(
    session: AsyncSession, user: User, profile: UserProfile, device_label: str | None
) -> AuthOut:
    """Creates an access token and a new refresh token for this device."""
    refresh_plain, refresh_hash = new_refresh_token()
    session.add(
        RefreshToken(
            user_id=user.id,
            token_hash=refresh_hash,
            device_label=device_label,
            expires_at=utcnow() + timedelta(days=settings.refresh_token_days),
        )
    )
    return AuthOut(
        access_token=create_token(str(user.id), "access", settings.access_token_minutes),
        refresh_token=refresh_plain,
        expires_in=settings.access_token_minutes * 60,
        user=build_me(user, profile),
    )
