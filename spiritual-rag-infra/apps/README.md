# Applications

Three services and their Kubernetes manifests. They run on the cluster built by stack 01, and their metrics are read by stack 02.

| Path | What it does | Runs on | Metrics |
|---|---|---|---|
| [`ingest/`](ingest) | PDF → text → normalized chunks (JSONL), optional upload to the bucket | Laptop, or a CPU job | None (batch) |
| [`train/`](train) | LoRA fine-tuning; pushes loss and throughput to Pushgateway | GPU node (job) | Pushgateway (`srag_train_*`) |
| [`rag-api/`](rag-api) | Retrieval from pgvector, answer generation through vLLM, citations | CPU node | `/metrics` (`srag_rag_*`) |
| [`k8s/inference-vllm.yaml`](k8s/inference-vllm.yaml) | vLLM server (OpenAI-compatible API) | GPU node | vLLM `/metrics` |
| [`k8s/rag-api.yaml`](k8s/rag-api.yaml) | Deployment, Service, ServiceMonitor for the RAG API | CPU node | Scraped by Prometheus |
| [`k8s/train-job.yaml`](k8s/train-job.yaml) | One-off training Job on the GPU pool | GPU node | Pushgateway |

## Order of operations

1. **Ingest** the corpus on a laptop or a small CPU job:
   ```bash
   cd apps/ingest && pip install -r requirements.txt
   python ingest.py --src ../../corpus --out chunks.jsonl
   ```
2. **Index** the chunks into pgvector. The schema is not in this repo yet. Create a table `passages` with columns `id text primary key, source text, page int, lang text, text text, embedding vector(768)`, then insert with the same embedding model that `rag-api` uses. This is a gap to close next.
3. **Deploy inference** (`k8s/inference-vllm.yaml`). It needs a GPU, so scale the GPU pool up first (`gpu_max_size = 1`).
4. **Deploy the RAG API** (`k8s/rag-api.yaml`). Create the `rag-api-secrets` Secret with `DATABASE_URL` first.
5. **Train** only if evaluation shows the base model needs it. `k8s/train-job.yaml` mounts training data from a ConfigMap, which suits only small datasets. Use a volume or a download step for large corpora.

## Placeholders to replace

- `REGISTRY` in the Kubernetes manifests: the container registry endpoint from stack 01.
- The model name `Qwen/Qwen2.5-7B-Instruct`: confirm the model and its license before use.
- `vllm/vllm-openai:latest`: pin a tag.
- The Secret name `rag-api-secrets`: create it outside Git.

## Known gaps

- The pgvector schema and the indexing step are described above but not written as code.
- `train.py` has not been run. It is a starting point for LoRA on the chat format, and the dataset format must match its `messages` input.
- No tests yet. Add a small test set for ingest chunking and the RAG prompt before relying on the output.
