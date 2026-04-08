import os
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration


def init_sentry() -> None:
    dsn = os.getenv("SENTRY_DSN")
    if not dsn:
        return
    sentry_sdk.init(
        dsn=dsn,
        integrations=[FastApiIntegration()],
        traces_sample_rate=0.2,
        environment=os.getenv("ENV", "development"),
    )


def capture(error: Exception) -> None:
    sentry_sdk.capture_exception(error)
