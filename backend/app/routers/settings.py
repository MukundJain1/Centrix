from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_session
from ..deps import current_profile
from ..models import UserProfile
from ..schemas import SettingsOut, SettingsUpdateIn

router = APIRouter(prefix="/v1/settings", tags=["settings"])


def _to_settings_out(profile: UserProfile) -> SettingsOut:
    return SettingsOut(
        grouping=profile.grouping,  # type: ignore[arg-type]
        week_start=profile.week_start,  # type: ignore[arg-type]
        default_calendar_view=profile.default_calendar_view,  # type: ignore[arg-type]
        budget_alerts=profile.budget_alerts,
        alert_threshold=profile.alert_threshold,
        daily_reminder=profile.daily_reminder,
        reminder_minutes=profile.reminder_minutes,
        app_lock=profile.app_lock,
        hide_balances=profile.hide_balances,
        payday=profile.payday,
    )


@router.get("", response_model=SettingsOut)
async def get_settings(profile: UserProfile = Depends(current_profile)):
    return _to_settings_out(profile)


@router.put("", response_model=SettingsOut)
async def put_settings(
    body: SettingsUpdateIn,
    profile: UserProfile = Depends(current_profile),
    session: AsyncSession = Depends(get_session),
):
    profile.grouping = body.grouping
    profile.week_start = body.week_start
    profile.default_calendar_view = body.default_calendar_view
    profile.budget_alerts = body.budget_alerts
    profile.alert_threshold = body.alert_threshold
    profile.daily_reminder = body.daily_reminder
    profile.reminder_minutes = body.reminder_minutes
    profile.app_lock = body.app_lock
    profile.hide_balances = body.hide_balances
    if body.payday is not None:
        profile.payday = body.payday
    await session.commit()
    return _to_settings_out(profile)


@router.post("/reset", response_model=SettingsOut)
async def reset_settings(
    profile: UserProfile = Depends(current_profile),
    session: AsyncSession = Depends(get_session),
):
    profile.grouping = "auto"
    profile.week_start = "monday"
    profile.default_calendar_view = "week"
    profile.budget_alerts = True
    profile.alert_threshold = 80
    profile.daily_reminder = False
    profile.reminder_minutes = 1260
    profile.app_lock = False
    profile.hide_balances = False
    await session.commit()
    return _to_settings_out(profile)