from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    env: str = "dev"  # dev | prod
    database_url: str = "sqlite+aiosqlite:///./dev.db"
    auto_create_tables: bool = False

    jwt_secret: str = "change-me"
    pin_pepper: str = "change-me-too"

    access_token_minutes: int = 15
    refresh_token_days: int = 30
    registration_token_minutes: int = 10

    # OTP
    otp_ttl_minutes: int = 5
    otp_max_attempts: int = 5
    otp_resend_seconds: int = 30
    otp_max_per_hour: int = 5
    dev_fixed_otp: str = "123456"

    # PIN lock
    pin_max_attempts: int = 5
    pin_lock_minutes: int = 15

    @property
    def is_dev(self) -> bool:
        return self.env == "dev"

    def check_production_ready(self) -> None:
        if self.is_dev:
            return
        weak = {"change-me", "change-me-too", ""}
        if self.jwt_secret in weak or self.pin_pepper in weak:
            raise RuntimeError("Set JWT_SECRET and PIN_PEPPER before running with ENV=prod.")
        if len(self.jwt_secret) < 32 or len(self.pin_pepper) < 32:
            raise RuntimeError("JWT_SECRET and PIN_PEPPER must be at least 32 characters long.")


settings = Settings()
