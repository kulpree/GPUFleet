"""RAG API: retrieve passages from pgvector, then answer with citations via vLLM.

Endpoints:
  POST /ask      {"question": "...", "top_k": 5}  -> answer + cited passages
  GET  /healthz  liveness
  GET  /metrics  Prometheus metrics (scraped by kube-prometheus-stack)

Environment:
  DATABASE_URL     postgres connection string (pgvector enabled)
  VLLM_URL         OpenAI-compatible base URL, e.g. http://inference-vllm:8000/v1
  VLLM_MODEL       model name served by vLLM
  EMBED_MODEL      sentence-transformers model, default multilingual e5
"""

from __future__ import annotations

import os
import time

import psycopg
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from prometheus_client import Counter, Histogram, make_asgi_app
from sentence_transformers import SentenceTransformer
import httpx

DATABASE_URL = os.environ["DATABASE_URL"]
VLLM_URL = os.environ["VLLM_URL"].rstrip("/")
VLLM_MODEL = os.environ["VLLM_MODEL"]
EMBED_MODEL = os.environ.get("EMBED_MODEL", "intfloat/multilingual-e5-base")

app = FastAPI(title="spiritual-rag-api")
app.mount("/metrics", make_asgi_app())

REQUESTS = Counter("srag_rag_requests_total", "RAG requests", ["status"])
LATENCY = Histogram("srag_rag_latency_seconds", "End-to-end RAG latency")
RETRIEVAL = Histogram("srag_rag_retrieval_seconds", "Vector search latency")

embedder = SentenceTransformer(EMBED_MODEL)


class AskRequest(BaseModel):
    question: str = Field(min_length=3, max_length=2000)
    top_k: int = Field(default=5, ge=1, le=20)


class Passage(BaseModel):
    id: str
    source: str
    page: int
    lang: str
    text: str
    distance: float


class AskResponse(BaseModel):
    answer: str
    citations: list[Passage]


SYSTEM_PROMPT = (
    "You answer questions using only the numbered passages provided. "
    "Cite passages by their number in square brackets, for example [2]. "
    "If the passages do not answer the question, say so. Do not invent sources. "
    "Answer in the same language as the question."
)


def retrieve(question: str, top_k: int) -> list[Passage]:
    # e5 models expect a "query: " prefix on queries.
    vector = embedder.encode(f"query: {question}", normalize_embeddings=True).tolist()
    with psycopg.connect(DATABASE_URL) as conn:
        rows = conn.execute(
            """
            SELECT id, source, page, lang, text, embedding <=> %s::vector AS distance
            FROM passages
            ORDER BY embedding <=> %s::vector
            LIMIT %s
            """,
            (vector, vector, top_k),
        ).fetchall()
    return [
        Passage(id=r[0], source=r[1], page=r[2], lang=r[3], text=r[4], distance=float(r[5]))
        for r in rows
    ]


def generate(question: str, passages: list[Passage]) -> str:
    context = "\n\n".join(f"[{i + 1}] ({p.source}, p.{p.page})\n{p.text}" for i, p in enumerate(passages))
    payload = {
        "model": VLLM_MODEL,
        "temperature": 0.2,
        "max_tokens": 600,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"Passages:\n{context}\n\nQuestion: {question}"},
        ],
    }
    response = httpx.post(f"{VLLM_URL}/chat/completions", json=payload, timeout=120)
    response.raise_for_status()
    return response.json()["choices"][0]["message"]["content"]


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.post("/ask", response_model=AskResponse)
def ask(req: AskRequest) -> AskResponse:
    started = time.perf_counter()
    try:
        with RETRIEVAL.time():
            passages = retrieve(req.question, req.top_k)
        if not passages:
            raise HTTPException(status_code=404, detail="no passages indexed")
        answer = generate(req.question, passages)
        REQUESTS.labels(status="ok").inc()
        return AskResponse(answer=answer, citations=passages)
    except HTTPException:
        REQUESTS.labels(status="not_found").inc()
        raise
    except Exception:
        REQUESTS.labels(status="error").inc()
        raise
    finally:
        LATENCY.observe(time.perf_counter() - started)
