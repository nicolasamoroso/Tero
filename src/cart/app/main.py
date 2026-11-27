import logging
import time

from fastapi import FastAPI, Request
from prometheus_fastapi_instrumentator import Instrumentator
from app.config import settings
from app.logging_config import setup_logging
from app.router import router

setup_logging()
logger = logging.getLogger("cart")

app = FastAPI(title="Cart Service")

SIN_LOG = {"/health", "/metrics"}


def nivel_por_status(status: int) -> int:
    if status >= 500:
        return logging.ERROR
    if status >= 400:
        return logging.WARNING
    return logging.INFO


@app.middleware("http")
async def log_requests(request: Request, call_next):
    inicio = time.perf_counter()
    status = 500
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:
        if request.url.path not in SIN_LOG:
            logger.log(
                nivel_por_status(status),
                "request",
                extra={
                    "method": request.method,
                    "path": request.url.path,
                    "status": status,
                    "duration_ms": round((time.perf_counter() - inicio) * 1000, 2),
                    "remote_ip": request.client.host if request.client else None,
                },
            )


@app.on_event("startup")
def startup():
    if settings.cart_persistence_provider == "postgres":
        from app.postgres_service import PostgresCartService
        app.state.cart_service = PostgresCartService()
    else:
        from app.service import InMemoryCartService
        app.state.cart_service = InMemoryCartService()


@app.get("/topology")
def topology():
    return {"provider": settings.cart_persistence_provider}


@app.get("/health")
def health():
    return {"status": "UP"}


app.include_router(router)
Instrumentator().instrument(app).expose(app, endpoint="/metrics")
