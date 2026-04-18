from __future__ import annotations

import json
import logging
import os
import time
from pathlib import Path
from typing import Any

import yaml
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, PlainTextResponse
from prometheus_client import start_http_server

from metrics import ADMISSIONS, DURATION, PATCHES, SKIPS
from registries import DEFAULT_RULES, Rewriter, load_rules

logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger("ecr-ptc-webhook")


def _load_rewriter() -> Rewriter:
    account_id = os.environ["ECR_REGISTRY_ACCOUNT_ID"]
    region = os.environ["ECR_REGISTRY_REGION"]

    config_path = os.getenv("REGISTRIES_CONFIG_PATH")
    if config_path and Path(config_path).exists():
        with open(config_path) as f:
            raw = yaml.safe_load(f) or {}
        rules_raw = raw.get("registries", DEFAULT_RULES)
    else:
        rules_raw = DEFAULT_RULES

    rules = load_rules(rules_raw)
    logger.info("Loaded %d registry rules: %s", len(rules), [r.host for r in rules])
    return Rewriter(aws_account_id=account_id, aws_region=region, rules=rules)


rewriter = _load_rewriter()
app = FastAPI(title="ecr-ptc-webhook")

_metrics_started = False


@app.on_event("startup")
async def _start_metrics_server() -> None:
    global _metrics_started
    if _metrics_started:
        return
    port = int(os.getenv("METRICS_PORT", "9090"))
    start_http_server(port)
    _metrics_started = True
    logger.info("Prometheus metrics listening on :%d/metrics", port)


@app.get("/")
async def root() -> str:
    return "ECR Pull-through webhook"


@app.get("/healthz")
async def healthz() -> PlainTextResponse:
    return PlainTextResponse("ok")


@app.post("/mutate")
async def mutate(request: Request) -> JSONResponse:
    start = time.perf_counter()
    try:
        req = await request.json()
    except Exception as exc:
        ADMISSIONS.labels(result="bad_request").inc()
        logger.error("Failed to parse admission review JSON: %s", exc)
        return JSONResponse(
            status_code=400,
            content={"response": {"allowed": True}},
        )

    admission_req = req.get("request") or {}
    uid = admission_req.get("uid", "")
    pod = admission_req.get("object") or {}

    patches = _build_patches(pod)

    admission_response: dict[str, Any] = {"uid": uid, "allowed": True}
    if patches:
        admission_response["patchType"] = "JSONPatch"
        admission_response["patch"] = _b64_json(patches)

    ADMISSIONS.labels(result="ok").inc()
    DURATION.observe(time.perf_counter() - start)

    return JSONResponse(
        content={
            "apiVersion": req.get("apiVersion", "admission.k8s.io/v1"),
            "kind": "AdmissionReview",
            "response": admission_response,
        }
    )


def _build_patches(pod: dict[str, Any]) -> list[dict[str, Any]]:
    patches: list[dict[str, Any]] = []
    spec = pod.get("spec") or {}
    for container_type in ("containers", "initContainers", "ephemeralContainers"):
        for i, container in enumerate(spec.get(container_type) or []):
            old = container.get("image", "")
            if not old:
                SKIPS.labels(reason="no_image").inc()
                continue
            new = rewriter.rewrite(old)
            if not new:
                SKIPS.labels(reason="no_rule").inc()
                continue
            if new == old:
                SKIPS.labels(reason="already_rewritten").inc()
                continue

            rule = rewriter.rule_for(old)
            prefix = rule.ecr_prefix if rule else "unknown"
            PATCHES.labels(ecr_prefix=prefix).inc()
            patches.append(
                {
                    "op": "replace",
                    "path": f"/spec/{container_type}/{i}/image",
                    "value": new,
                }
            )
            logger.info("Rewrote %s[%d]: %s -> %s", container_type, i, old, new)
    return patches


def _b64_json(patches: list[dict[str, Any]]) -> str:
    import base64

    return base64.b64encode(json.dumps(patches).encode("utf-8")).decode("ascii")
