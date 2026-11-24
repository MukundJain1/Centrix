import re

from .errors import ApiError


def normalize_phone(dial_code: str, national_number: str, country_iso: str) -> str:
    """('+91', '98765 43210', 'IN') -> '+919876543210'"""
    dial = re.sub(r"\D", "", dial_code)
    digits = re.sub(r"\D", "", national_number).lstrip("0")

    if country_iso.upper() == "IN":
        if not re.fullmatch(r"[6-9]\d{9}", digits):
            raise ApiError(422, "INVALID_PHONE", "Enter a valid 10-digit mobile number.")
    elif not (6 <= len(digits) <= 14):
        raise ApiError(422, "INVALID_PHONE", "Enter a valid mobile number.")

    if not dial or len(dial) + len(digits) > 15:
        raise ApiError(422, "INVALID_PHONE", "Enter a valid mobile number.")
    return f"+{dial}{digits}"
