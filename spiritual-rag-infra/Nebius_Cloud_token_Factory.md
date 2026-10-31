# Nebius AI Cloud and Token Factory: Use Cases and Benefits

This document covers Nebius AI Cloud as the infrastructure layer and Nebius Token Factory as the managed inference layer. It explains what each one does, when to use each, and how they fit the Spiritual RAG project.

> **Scope note:** Vendor pricing and feature lists change often. Figures here come from Nebius pages and third-party summaries read in October 2026. Check the live pricing page before you commit budget.

---

## 1. The two products at a glance

| | Nebius AI Cloud | Nebius Token Factory |
|---|---|---|
| What it is | GPU cloud infrastructure: virtual machines, GPU clusters, managed Kubernetes, storage, registry, databases | Managed inference platform for open-weight models, reached through an API |
| You manage | Machines, clusters, and the software on them (or Kubernetes workloads) | Only the API calls and your model choices |
| You pay for | GPU and CPU hours, storage, egress | Tokens processed (pay-as-you-go), or dedicated endpoints |
| Typical user | Teams that train models, run their own serving stack, or need full control | Teams that want to call open models through an API without running GPUs |
| Terraform | Yes: `nebius/nebius` provider | Managed through the web console and API |

Nebius describes Token Factory as an OpenAI-compatible platform for inference and fine-tuning, which means many existing OpenAI client libraries work with it after changing the base URL and API key.

---

## 2. Nebius AI Cloud

### What it offers

Nebius AI Cloud provides GPU virtual machines and clusters, managed Kubernetes, S3-compatible Object Storage, a container registry, managed PostgreSQL, MLflow, and Slurm on Kubernetes through Soperator. A Terraform provider and a CLI cover provisioning. Source: [Nebius AI Cloud service catalog as summarized by APIEvangelist](https://providers.apievangelist.com/providers/nebius/).

### Benefits

- **Managed Kubernetes with GPU support.** The control plane is managed. GPU node groups come with NVIDIA drivers and device plugins preinstalled, so you do not run the GPU operator yourself. Worker nodes are billed only while they run. Source: [Seqera's write-up on Nebius MK8s](https://seqera.io/blog/deploying-gpu-accelerated-nextflow-pipelines-on-nebius-kubernetes-with-seqera/).
- **Everything as code.** Nebius resources can be managed through the Terraform provider, so cluster configuration is version-controlled. This project uses it for both stacks.
- **S3-compatible storage.** Standard S3 tools and SDKs work with Object Storage, which suits a corpus of PDFs and chunks.
- **European regions.** Nebius is headquartered in Amsterdam. For data residency reasons, check which regions meet your requirements.

### Good uses

- Training and fine-tuning models where you control the hardware and the software.
- Running your own inference server (vLLM, for example) for full control over latency, batching, and model versions.
- Hosting a RAG pipeline that needs custom indexing, storage, and GPU workloads.
- Batch GPU jobs such as embedding millions of chunks.

### Trade-offs

- You are responsible for the cluster, the GPU drivers in your images, patching of your workloads, and idle GPU cost.
- GPU hours are billed even when the GPU is idle, unless the pool scales to zero.
- Setup takes more work than an API call.

---

## 3. Nebius Token Factory

### What it offers

Token Factory is a platform that serves open-weight models behind one API. Nebius says it offers more than 60 open-source models across text, code, vision, reasoning, image generation, and embeddings, including DeepSeek, GPT-OSS, Llama, Qwen, Mistral, and NVIDIA Nemotron. Sources: [Nebius Token Factory](https://nebius.com/services/token-factory), [G2 product listing](https://www.g2.com/sellers/nebius).

### The API

The API is OpenAI-compatible. Nebius's documentation uses this base URL and pattern:

```python
import os
from openai import OpenAI

client = OpenAI(
    base_url="https://api.tokenfactory.nebius.com/v1/",
    api_key=os.environ.get("NEBIUS_API_KEY"),
)

response = client.chat.completions.create(
    model="deepseek-ai/DeepSeek-R1-0528",
    messages=[{"role": "user", "content": "Explain retrieval-augmented generation in one paragraph."}],
)
print(response.choices[0].message.content)
```

Source: [Nebius Token Factory documentation](https://docs.tokenfactory.nebius.com/). Create an API key in the Token Factory console under API keys. Nebius shows the key only once, so save it in a secrets manager.

Capabilities listed for the API include chat completions, text, code, reasoning, vision, embeddings, function calling, and structured JSON output. Support varies by model, so check each model's card. Source: [Eden AI provider page](https://www.edenai.co/providers/nebius).

### Ways to run models

| Option | What it is | Best for |
|---|---|---|
| **Shared (serverless) endpoints** | Pay per token on shared capacity | Prototyping, low to medium volume, unpredictable traffic |
| **Dedicated endpoints** | Single-tenant capacity with guaranteed throughput and a 99.9% SLA, with autoscaling | Production workloads with steady volume and latency targets |
| **Your own checkpoints** | Deploy a fine-tuned model on a Token Factory endpoint | Teams that fine-tune and want managed serving |

Sources: [Token Factory inference service](https://nebius.com/services/token-factory/inference-service), [Token Factory text page](https://nebius.com/services/token-factory/text-to-image).

### Other capabilities

- **Fine-tuning.** Adapt models to your data, then deploy the result on a Token Factory endpoint. The API supports fine-tuning jobs. Source: [API introduction](https://docs.tokenfactory.nebius.com/api-reference/introduction).
- **Batch inference.** Process large datasets asynchronously. Sources: [Eden AI](https://www.edenai.co/providers/nebius), [Nexla connector reference](https://docs.nexla.com/user-guides/connectors/nebius_ai_api), which lists batch and fine-tuning endpoints.
- **Embeddings and RAG tools.** Nebius describes embedding models and PGVector-backed storage in the same platform, so indexing, retrieval, and inference can stay in one environment. Source: [Token Factory text page](https://nebius.com/services/token-factory/text-to-image).
- **Playground.** A web playground lets you compare models and export the code for a chat. Source: [API introduction](https://docs.tokenfactory.nebius.com/api-reference/introduction).
- **Integrations.** Third-party framework integrations are listed in the documentation. The cookbook is at [github.com/nebius/token-factory-cookbook](https://github.com/nebius/token-factory-cookbook).

### Security and governance

- **Zero-retention mode.** Nebius says requests and outputs are not stored or reused for training in this mode. Source: [Eden AI provider page](https://www.edenai.co/providers/nebius), which summarizes Nebius's statement. Confirm the exact terms in Nebius's contract before relying on it for sensitive text.
- **Certifications.** Nebius states its processing facilities hold SOC 2 Type II, ISO 27001, and HIPAA certifications. Source: [Eden AI provider page](https://www.edenai.co/providers/nebius). Ask for current audit reports under NDA if you need them.
- **Access control.** Teams, access management, SSO, and project separation are listed. Source: [G2 listing](https://www.g2.com/sellers/nebius).

---

## 4. Benefits of Token Factory

1. **No GPU to manage.** You do not provision, patch, or scale GPU nodes. This removes a large share of the operational work in the self-hosted design in this repo.
2. **No idle cost on shared endpoints.** Pay per token, so there is no GPU-hour bill when no one is asking questions. This matters with a USD 100 budget: an idle H100 at about USD 4.50 per hour costs more in a day than many small workloads cost in a month.
3. **Model choice without re-integration.** The OpenAI-compatible API lets you switch models by changing a model name. You can compare several open models without writing new integration code.
4. **Predictable production options.** Dedicated endpoints offer a 99.9% SLA and autoscaling throughput, according to Nebius.
5. **Open models, not a single vendor's model.** You can choose models with licenses that fit your use, such as Apache 2.0 or MIT, and check the license for each one.
6. **Same vendor as the infrastructure.** If you later self-host on Nebius AI Cloud, the account, billing, and regions are the same.

### Nebius's performance claims

Nebius says time to first token is up to 4.5 times faster in Europe than other providers, based on its own comparison and independent tests. Treat this as a vendor claim, and benchmark on your own prompts. Source: [Token Factory inference service](https://nebius.com/services/studio-inference-service).

Nebius also says solution architects can help reduce inference costs by up to 70% through distillation, speculative decoding, and model right-sizing. This is a vendor claim, not a guarantee. Source: [Token Factory enterprise page](https://nebius.com/services/token-factory/enterprise-grade-inference).

---

## 5. Pricing

Token Factory uses transparent per-token pricing for shared and dedicated tiers, with volume discounts for production. Source: [Token Factory prices](https://nebius.com/services/token-factory).

Third-party trackers report input prices from about USD 0.06 to USD 3.00 per million tokens across the models they list. Those figures are not from Nebius, and they change. Source: [Eden AI provider page](https://www.edenai.co/providers/nebius).

**Enterprise plan:** Nebius lists pay-as-you-go for the starter plan, and custom usage commits with post-paid billing and volume discounts for the enterprise plan. Source: [Token Factory enterprise page](https://nebius.com/services/token-factory/enterprise-grade-inference).

### Rough comparison for this project

| Option | Cost driver | Cost when idle | Control |
|---|---|---|---|
| Self-hosted vLLM on one H100 (this repo) | GPU hours | Yes, unless the pool is scaled to zero | Full |
| Token Factory shared endpoint | Tokens | No | Model choice only |
| Token Factory dedicated endpoint | Dedicated capacity (check price) | Likely yes | Model and capacity |

The break-even point depends on your token volume. Compare cost per 1,000 requests for your real prompts before choosing. A simple way to estimate:

```
monthly cost (shared)     = (input tokens + output tokens) / 1,000,000 × price per million
monthly cost (self-host)  = GPU hourly rate × hours the GPU runs
```

Run both numbers with your average request size and expected daily volume.

---

## 6. How Token Factory fits the Spiritual RAG project

| Need | Token Factory option | Note |
|---|---|---|
| Answer generation | Shared endpoint with a multilingual open model | No GPU needed; costs follow usage |
| Embeddings for chunks | Embedding model on the platform | Check that the model covers the languages you need |
| Fine-tuned answer model | Deploy your own checkpoint on an endpoint | Requires a training run first (`apps/train`) |
| Corpus indexing | Pgvector storage in the platform, or your own pgvector on Nebius managed PostgreSQL | Keep vectors in your database for control |
| Monitoring | Your own Prometheus stack reads token and latency data only if the platform exposes it | Check what metrics the API returns; otherwise instrument the RAG API (`apps/rag-api`) |

**Practical suggestion:** start with a Token Factory shared endpoint for the RAG answer model. It keeps the budget safe and avoids idle GPU cost. Keep the self-hosted vLLM manifest in the repo for later, when volume or data-control needs justify a GPU.

**Trade-off to note:** if you use Token Factory, the `inference-vllm.yaml` deployment and the vLLM dashboard in stack 02 are not needed for answer generation. You would instrument the RAG API for latency and token counts instead.

---

## 7. Limits and cautions

- **Model availability changes.** Models are added and retired. Pin model names in code and check the model list before each release.
- **Batch API documentation is inconsistent across sources.** One gateway vendor's compatibility page says Nebius does not publish OpenAI-compatible batch routes. Nexla and Eden AI describe Nebius batch processing. Check the current Token Factory API reference before building on batch.
- **Third-party figures are not Nebius figures.** Treat price ranges and comparisons from aggregators as estimates.
- **Vendor performance claims need your own test.** Measure latency and quality on your Qwen, Llama, or other candidate models with your real questions in each language.
- **Data handling.** Confirm the zero-retention mode, data location, and terms in your contract before sending sensitive religious or personal text.
- **Lock-in.** The API is OpenAI-compatible, which lowers switching cost. Keep prompts, retrieval, and evaluation in your own code so you can move the model later.

---

## 8. References

| Topic | Source | Read in this session |
|---|---|---|
| Token Factory overview | https://nebius.com/services/token-factory | Search excerpt |
| Token Factory inference service | https://nebius.com/services/token-factory/inference-service | Search excerpt |
| Token Factory enterprise plans | https://nebius.com/services/token-factory/enterprise-grade-inference | Search excerpt |
| Token Factory text and RAG page | https://nebius.com/services/token-factory/text-to-image | Search excerpt |
| Token Factory API documentation | https://docs.tokenfactory.nebius.com/ | Search excerpt |
| API introduction and authentication | https://docs.tokenfactory.nebius.com/api-reference/introduction | Search excerpt |
| API examples | https://docs.tokenfactory.nebius.com/api-reference/examples/overview | Search excerpt |
| Cookbook | https://github.com/nebius/token-factory-cookbook | Linked only |
| Provider summary (third party) | https://www.edenai.co/providers/nebius | Search excerpt |
| Batch and fine-tuning endpoints (third party) | https://docs.nexla.com/user-guides/connectors/nebius_ai_api | Search excerpt |
| Gateway compatibility notes (third party) | https://fuma-docs.api7.ai/ai-gateway/providers/nebius-token-factory | Search excerpt |
| Nebius AI Cloud service summary (third party) | https://providers.apievangelist.com/providers/nebius/ | Search excerpt |
| Managed Kubernetes with Nebius (case study) | https://seqera.io/blog/deploying-gpu-accelerated-nextflow-pipelines-on-nebius-kubernetes-with-seqera/ | Search excerpt |
| Nebius pricing | https://nebius.com/prices | Linked only; not read |
| Nebius Terraform provider | https://docs.nebius.com/terraform-provider | Read in earlier work |

"Search excerpt" means the statement was read in a search result, not in the full page. Open the linked page before quoting it.