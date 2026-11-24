import calendar
from datetime import date


def _clamped(year: int, month: int, day: int) -> date:
    """Payday 31 in a 30-day month means the 30th."""
    return date(year, month, min(day, calendar.monthrange(year, month)[1]))


def days_until_payday(today: date, payday: int) -> int:
    """Days from today to the next payday (at least 1).

    If today is payday, the next one is next month.
    """
    candidate = _clamped(today.year, today.month, payday)
    if candidate <= today:
        year, month = (today.year + 1, 1) if today.month == 12 else (today.year, today.month + 1)
        candidate = _clamped(year, month, payday)
    return (candidate - today).days


def days_in_month(today: date) -> int:
    return calendar.monthrange(today.year, today.month)[1]
