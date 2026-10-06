"""FastAPI 版 — hello-go と同じ Platform Contract を満たす 20% 側の差し替え例（Phase 10）。

Contract: PORT / GET /healthz / GET /readyz / GET /metrics / JSON ログ / SIGTERM で終了
"""
import os
import time

from fastapi import FastAPI, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

MESSAGE = os.environ.get("APP_MESSAGE")
if not MESSAGE:
    raise SystemExit("APP_MESSAGE is required (check ConfigMap)")

app = FastAPI()
REQUESTS = Counter("http_requests_total", "Total HTTP requests", ["method", "path", "code"])
LATENCY = Histogram("http_request_duration_seconds", "HTTP request latency", ["path"])


@app.middleware("http")
async def instrument(request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    path = request.url.path if request.url.path in {"/", "/healthz", "/readyz", "/metrics"} else "other"
    REQUESTS.labels(request.method, path, str(response.status_code)).inc()
    LATENCY.labels(path).observe(time.perf_counter() - start)
    return response


@app.get("/")
def root():
    return Response(f"{MESSAGE} (version={os.environ.get('APP_VERSION', 'dev')}, pod={os.uname().nodename})\n",
                    media_type="text/plain")


@app.get("/healthz")
def healthz():
    return Response("ok", media_type="text/plain")


@app.get("/readyz")
def readyz():
    return Response("ready", media_type="text/plain")


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
