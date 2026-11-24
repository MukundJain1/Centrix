from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


class ApiError(Exception):
    """Every error the API returns has this shape:

        {"error": {"code": "WRONG_PIN", "message": "...", ...extra fields}}

    The Flutter app switches on `code` (stable) and may show `message`.
    """

    def __init__(self, status_code: int, code: str, message: str, **extra):
        self.status_code = status_code
        self.code = code
        self.message = message
        self.extra = extra


async def api_error_handler(_: Request, exc: ApiError) -> JSONResponse:
    headers = {}
    if "retry_after" in exc.extra:
        headers["Retry-After"] = str(exc.extra["retry_after"])
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": {"code": exc.code, "message": exc.message, **exc.extra}},
        headers=headers,
    )


async def validation_error_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
    fields = [
        {"field": ".".join(str(p) for p in e["loc"] if p != "body"), "problem": e["msg"]}
        for e in exc.errors()
    ]
    return JSONResponse(
        status_code=422,
        content={"error": {"code": "VALIDATION_ERROR", "message": "Please check your input.", "fields": fields}},
    )
