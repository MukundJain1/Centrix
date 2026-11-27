from datetime import date, datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field

# ------------------------------------------------------------------- auth

class PhoneIn(BaseModel):
    dial_code: str = Field(pattern=r"^\+?\d{1,4}$", examples=["+91"])
    phone: str = Field(min_length=4, max_length=20, examples=["9876543210"])
    country_iso: str = Field(default="IN", min_length=2, max_length=2)


class OtpVerifyIn(PhoneIn):
    code: str = Field(pattern=r"^\d{4,8}$")


class RegisterIn(BaseModel):
    registration_token: str
    pin: str = Field(pattern=r"^\d{4,6}$")
    device_label: str | None = Field(default=None, max_length=80)


class LoginIn(PhoneIn):
    pin: str = Field(pattern=r"^\d{4,6}$")
    device_label: str | None = Field(default=None, max_length=80)


class RefreshIn(BaseModel):
    refresh_token: str


class OtpSentOut(BaseModel):
    expires_in: int
    resend_in: int
    dev_hint: str | None = None  # only in ENV=dev


class RegistrationTokenOut(BaseModel):
    registration_token: str
    expires_in: int


# --------------------------------------------------------------------- me

class OnboardingOut(BaseModel):
    baseline_done: bool
    cycle_done: bool


class MeOut(BaseModel):
    id: str
    phone: str
    country_iso: str
    full_name: str | None = None
    age: int | None = None
    date_of_birth: date | None = None
    gender: str | None = None
    occupation: str | None = None
    currency: str
    monthly_surplus: float | None
    daily_limit: float | None
    payday: int | None
    created_at: datetime
    onboarding: OnboardingOut


class PinVerifyIn(BaseModel):
    pin: str = Field(pattern=r"^\d{4,6}$")


class PinVerifyOut(BaseModel):
    verified: bool = True


class SettingsOut(BaseModel):
    grouping: Literal["auto", "indian", "international"]
    week_start: Literal["monday", "sunday", "saturday"]
    default_calendar_view: Literal["week", "month"]
    budget_alerts: bool
    alert_threshold: int
    daily_reminder: bool
    reminder_minutes: int
    app_lock: bool
    hide_balances: bool
    payday: int | None


class SettingsUpdateIn(BaseModel):
    grouping: Literal["auto", "indian", "international"] = "auto"
    week_start: Literal["monday", "sunday", "saturday"] = "monday"
    default_calendar_view: Literal["week", "month"] = "week"
    budget_alerts: bool = True
    alert_threshold: int = Field(default=80, ge=50, le=100)
    daily_reminder: bool = False
    reminder_minutes: int = Field(default=1260, ge=0, le=1439)
    app_lock: bool = False
    hide_balances: bool = False
    payday: int | None = Field(default=None, ge=1, le=31)


class ProfileUpdateIn(BaseModel):
    full_name: str | None = Field(default=None, max_length=80)
    age: int | None = Field(default=None, ge=1, le=999)
    date_of_birth: date | None = None
    gender: str | None = Field(default=None, max_length=32)
    occupation: str | None = Field(default=None, max_length=60)


class AuthOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: MeOut


# --------------------------------------------------------------- baseline

class ItemIO(BaseModel):
    name: str = Field(default="", max_length=60)
    amount: Decimal = Field(default=Decimal("0"), ge=0, le=Decimal("9999999999"), decimal_places=2)


class CategoryIO(BaseModel):
    title: str = Field(default="", max_length=60)
    is_income: bool = False
    is_custom: bool = False
    items: list[ItemIO] = Field(default_factory=list, max_length=50)


class BaselineIn(BaseModel):
    currency: str = Field(default="₹", min_length=1, max_length=8)
    categories: list[CategoryIO] = Field(max_length=30)


class ItemOut(BaseModel):
    name: str
    amount: float


class CategoryOut(BaseModel):
    title: str
    is_income: bool
    is_custom: bool
    items: list[ItemOut]


class BaselineOut(BaseModel):
    currency: str
    categories: list[CategoryOut]
    monthly_surplus: float | None
    daily_limit: float | None


class CycleIn(BaseModel):
    payday: int = Field(ge=1, le=31)
    current_balance: Decimal = Field(gt=0, le=Decimal("9999999999"), decimal_places=2)
    # The phone's local date. Defaults to the server's UTC date.
    client_date: date | None = None
