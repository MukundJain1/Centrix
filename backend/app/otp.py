import logging
from typing import Protocol

from .config import settings
from .errors import ApiError

log = logging.getLogger("otp")


class OtpSender(Protocol):
    async def send(self, phone_e164: str, code: str) -> None: ...


class ConsoleOtpSender:
    """Development only: prints the code in the server log, sends nothing."""

    async def send(self, phone_e164: str, code: str) -> None:
        log.warning("DEV OTP for %s is %s", phone_e164, code)


def get_otp_sender() -> OtpSender:
    if settings.is_dev:
        return ConsoleOtpSender()
    # TODO: return your real provider here (MSG91, Twilio, Firebase ...).
    # It only needs an `async def send(self, phone_e164, code)` method.
    raise ApiError(503, "SMS_NOT_CONFIGURED", "SMS sending is not configured on the server yet.")
