from contextlib import asynccontextmanager
import logging
import os
import time
from pathlib import Path

import asyncpg
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Response
from fastapi.responses import RedirectResponse
from prometheus_client import Counter, Gauge, Histogram, CONTENT_TYPE_LATEST, generate_latest
from routers.journal_router import router as journal_router

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
logger = logging.getLogger("learningsteps")
REQUESTS = Counter("learningsteps_http_requests_total", "HTTP-Anfragen", ["method", "route", "status"])
LATENCY = Histogram("learningsteps_http_duration_seconds", "Antwortdauer", ["route"])
DB_UP = Gauge("learningsteps_database_up", "Datenbank erreichbar")


def database_url():
    secret_file = os.getenv("DATABASE_URL_FILE")
    return Path(secret_file).read_text().strip() if secret_file else os.environ["DATABASE_URL"]


@asynccontextmanager
async def lifespan(app):
    app.state.pool = await asyncpg.create_pool(database_url(), min_size=1, max_size=5, command_timeout=10)
    logger.info("LearningSteps gestartet")
    yield
    await app.state.pool.close()


app = FastAPI(title="LearningSteps API", description="Lerntagebuch mit automatisiertem Cloud-Betrieb", lifespan=lifespan)
app.include_router(journal_router)


@app.middleware("http")
async def metrics(request, call_next):
    started = time.perf_counter()
    status = 500
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:
        route = getattr(request.scope.get("route"), "path", "unmatched")
        if route not in ("/metrics", "/health/live", "/health/ready"):
            REQUESTS.labels(request.method, route, str(status)).inc()
            LATENCY.labels(route).observe(time.perf_counter() - started)


@app.get("/health/live", tags=["Betrieb"])
async def live():
    return {"status": "ok"}


@app.get("/health/ready", tags=["Betrieb"])
async def ready():
    try:
        await app.state.pool.fetchval("SELECT 1 FROM entries LIMIT 1", timeout=3)
        DB_UP.set(1)
    except Exception:
        DB_UP.set(0)
        raise HTTPException(503, "Datenbank nicht bereit") from None
    return {"status": "ready"}


@app.get("/metrics", include_in_schema=False)
async def prometheus():
    try:
        await app.state.pool.fetchval("SELECT 1", timeout=3)
        DB_UP.set(1)
    except Exception:
        DB_UP.set(0)
    return Response(generate_latest(), headers={"Content-Type": CONTENT_TYPE_LATEST})


@app.get("/", include_in_schema=False)
def root():
    return RedirectResponse(url="/docs")
