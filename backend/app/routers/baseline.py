from datetime import date
from decimal import Decimal

from fastapi import APIRouter, Depends
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..cycle import days_in_month, days_until_payday
from ..db import get_session
from ..deps import current_profile, current_user
from ..models import BaselineCategory, BaselineItem, User, UserProfile
from ..schemas import BaselineIn, BaselineOut, CategoryOut, CycleIn, ItemOut, MeOut
from ..services import build_me
from ..timeutil import utcnow

router = APIRouter(prefix="/v1", tags=["baseline"])

TWO_PLACES = Decimal("0.01")


async def _load_baseline(session: AsyncSession, user: User, profile: UserProfile) -> BaselineOut:
    categories = (
        await session.scalars(
            select(BaselineCategory)
            .where(BaselineCategory.user_id == user.id)
            .order_by(BaselineCategory.sort_order)
        )
    ).all()
    items = (
        await session.scalars(
            select(BaselineItem).where(BaselineItem.user_id == user.id).order_by(BaselineItem.sort_order)
        )
    ).all()

    by_category: dict = {}
    for item in items:
        by_category.setdefault(item.category_id, []).append(ItemOut(name=item.name, amount=float(item.amount)))

    return BaselineOut(
        currency=profile.currency,
        categories=[
            CategoryOut(
                title=c.title,
                is_income=c.is_income,
                is_custom=c.is_custom,
                items=by_category.get(c.id, []),
            )
            for c in categories
        ],
        monthly_surplus=float(profile.monthly_surplus) if profile.monthly_surplus is not None else None,
        daily_limit=float(profile.daily_limit) if profile.daily_limit is not None else None,
    )


@router.get("/baseline", response_model=BaselineOut)
async def get_baseline(
    user: User = Depends(current_user),
    profile: UserProfile = Depends(current_profile),
    session: AsyncSession = Depends(get_session),
):
    """What the user entered in Financial Baseline (empty list if never saved)."""
    return await _load_baseline(session, user, profile)


@router.put("/baseline", response_model=BaselineOut)
async def put_baseline(
    body: BaselineIn,
    user: User = Depends(current_user),
    profile: UserProfile = Depends(current_profile),
    session: AsyncSession = Depends(get_session),
):
    """Saves the whole baseline (replaces the old one) and recalculates the surplus."""
    await session.execute(delete(BaselineItem).where(BaselineItem.user_id == user.id))
    await session.execute(delete(BaselineCategory).where(BaselineCategory.user_id == user.id))

    income = Decimal("0")
    expenses = Decimal("0")
    for c_index, category in enumerate(body.categories):
        row = BaselineCategory(
            user_id=user.id,
            title=category.title.strip(),
            is_income=category.is_income,
            is_custom=category.is_custom,
            sort_order=c_index,
        )
        session.add(row)
        await session.flush()  # we need row.id for the items
        for i_index, item in enumerate(category.items):
            session.add(
                BaselineItem(
                    category_id=row.id,
                    user_id=user.id,
                    name=item.name.strip(),
                    amount=item.amount,
                    sort_order=i_index,
                )
            )
            if category.is_income:
                income += item.amount
            else:
                expenses += item.amount

    surplus = (income - expenses).quantize(TWO_PLACES)
    profile.currency = body.currency
    profile.monthly_surplus = surplus
    if profile.baseline_completed_at is None:
        profile.baseline_completed_at = utcnow()

    # Before the cycle step is done, the daily budget is simply surplus / days.
    # After that, the payday-based budget (PUT /v1/cycle) stays in charge.
    if profile.cycle_completed_at is None:
        per_day = surplus / days_in_month(date.today()) if surplus > 0 else Decimal("0")
        profile.daily_limit = per_day.quantize(TWO_PLACES)

    await session.commit()
    return await _load_baseline(session, user, profile)


@router.put("/cycle", response_model=MeOut)
async def put_cycle(
    body: CycleIn,
    user: User = Depends(current_user),
    profile: UserProfile = Depends(current_profile),
    session: AsyncSession = Depends(get_session),
):
    """Payday + money left now -> daily budget until the next payday."""
    today = body.client_date or date.today()
    days = days_until_payday(today, body.payday)
    profile.payday = body.payday
    profile.daily_limit = (body.current_balance / days).quantize(TWO_PLACES)
    profile.cycle_completed_at = utcnow()
    await session.commit()
    return build_me(user, profile)
