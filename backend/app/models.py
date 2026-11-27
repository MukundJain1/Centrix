"""Database tables. supabase/schema.sql must stay in sync with this file."""
import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    SmallInteger,
    String,
    Text,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base
from .timeutil import utcnow


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    phone_e164: Mapped[str] = mapped_column(String(20), unique=True)
    country_iso: Mapped[str] = mapped_column(String(2), default="IN")
    pin_hash: Mapped[str] = mapped_column(Text)
    failed_pin_attempts: Mapped[int] = mapped_column(Integer, default=0)
    locked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)


class UserProfile(Base):
    __tablename__ = "user_profiles"
    __table_args__ = (
        CheckConstraint("payday between 1 and 31", name="payday_range"),
        CheckConstraint("age between 1 and 999", name="age_range"),
        CheckConstraint("alert_threshold between 50 and 100", name="alert_threshold_range"),
        CheckConstraint("reminder_minutes between 0 and 1439", name="reminder_minutes_range"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    full_name: Mapped[str | None] = mapped_column(String(80))
    age: Mapped[int | None] = mapped_column(SmallInteger)
    date_of_birth: Mapped[date | None] = mapped_column(Date)
    gender: Mapped[str | None] = mapped_column(String(32))
    occupation: Mapped[str | None] = mapped_column(String(60))
    currency: Mapped[str] = mapped_column(String(8), default="₹")
    monthly_surplus: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    daily_limit: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    payday: Mapped[int | None] = mapped_column(SmallInteger)
    grouping: Mapped[str] = mapped_column(String(16), default="auto")
    week_start: Mapped[str] = mapped_column(String(12), default="monday")
    default_calendar_view: Mapped[str] = mapped_column(String(10), default="week")
    budget_alerts: Mapped[bool] = mapped_column(Boolean, default=True)
    alert_threshold: Mapped[int] = mapped_column(SmallInteger, default=80)
    daily_reminder: Mapped[bool] = mapped_column(Boolean, default=False)
    reminder_minutes: Mapped[int] = mapped_column(SmallInteger, default=1260)
    app_lock: Mapped[bool] = mapped_column(Boolean, default=False)
    hide_balances: Mapped[bool] = mapped_column(Boolean, default=False)
    baseline_completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cycle_completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

class OtpChallenge(Base):
    __tablename__ = "otp_challenges"
    __table_args__ = (Index("ix_otp_phone_created", "phone_e164", "created_at"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    phone_e164: Mapped[str] = mapped_column(String(20))
    country_iso: Mapped[str] = mapped_column(String(2), default="IN")
    code_hash: Mapped[str] = mapped_column(Text)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    device_label: Mapped[str | None] = mapped_column(String(80))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class BaselineCategory(Base):
    __tablename__ = "baseline_categories"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    title: Mapped[str] = mapped_column(String(60), default="")
    is_income: Mapped[bool] = mapped_column(Boolean, default=False)
    is_custom: Mapped[bool] = mapped_column(Boolean, default=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class BaselineItem(Base):
    __tablename__ = "baseline_items"
    __table_args__ = (CheckConstraint("amount >= 0", name="amount_non_negative"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    category_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("baseline_categories.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(60), default="")
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), default=Decimal("0"))
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
