# Spiritual-RAG on Nebius: Multi-Region Kubernetes, Training/Inference, and Monitoring

Two Terraform stacks that provision a GPU-ready Kubernetes platform on [Nebius AI Cloud](https://nebius.com), plus an open-source observability stack for system, GPU, training, inference, and cost metrics. Both stacks run on [HCP Terraform](https://developer.hashicorp.com/terraform/cloud-docs). The workload is a retrieval-augmented generation (RAG) model over a multilingual corpus of religious and spiritual texts (PDF scriptures, commentaries, and translations).

> **Budget:** this project is designed around a **USD 100 total budget** for Nebius. Read [Cost controls](#cost-controls) before you run anything. GPU time is the dominant cost and is billed per hour. HCP Terraform is billed separately and is covered there too.

---

## Contents

- [Architecture](#architecture)
- [Repository layout](#repository-layout)
- [HCP Terraform setup](#hcp-terraform-setup)
- [Quick start](#quick-start)
- [Stack 1: Platform](#stack-1-platform)
- [Stack 2: Observability](#stack-2-observability)
- [Data pipeline (PDF to RAG)](#data-pipeline-pdf-to-rag)
- [Monitoring](#monitoring)
- [Cost controls](#cost-controls)
- [Security notes](#security-notes)
- [Teardown](#teardown)
- [Roadmap](#roadmap)

---

## Architecture

```
                 ┌──────────────────────── Nebius AI Cloud ────────────────────────┐
  PDFs / text ─► │ Object Storage (S3-compatible)  ── raw/ , chunks/ , eval/        │
                 │          │                                                      │
                 │          ▼                                                      │
                 │ Region A (primary, GPU)           Region B (optional, CPU/RAG) │
                 │ ┌────────────────────────┐        ┌──────────────────────────┐  │
                 │ │ Managed Kubernetes     │        │ Managed Kubernetes       │  │
                 │ │  - train (GPU pool)    │ ◄────► │  - RAG API (CPU pool)    │  │
                 │ │  - inference (GPU pool)│  GitOps│  - Vector store replica  │  │
                 │ │  - vector DB           │        │                          │  │
                 │ └──────────┬─────────────┘        └────────────┬─────────────┘  │
                 │            │ metrics / logs / traces           │                │
                 │            ▼                                   ▼                │
                 │      Observability stack (Prometheus, Grafana, Loki, OpenCost)  │
                 └─────────────────────────────────────────────────────────────────┘
                                   ▲ provisioned by
                 ┌──────────────── HCP Terraform (remote state + runs) ────────────┐
                 │  workspace: spiritual-rag-platform-<profile>                    │
                 │  workspace: spiritual-rag-observability                         │
                 └─────────────────────────────────────────────────────────────────┘
```

**Design choices**

| Concern | Choice | Why |
|---|---|---|
| Kubernetes | Nebius Managed Kubernetes (MK8s) | Managed control plane. Worker nodes are billed only while running. GPU node groups ship with NVIDIA drivers and device plugins preinstalled. |
| IaC runtime | HCP Terraform remote runs, one workspace per stack and profile | State is locked and versioned. Runs are auditable. Secrets stay out of your laptop and out of git. |
| "Federated" multi-region | Independent clusters managed by GitOps (Argo CD `ApplicationSet`), with an optional Karmada layer later | KubeFed is no longer actively maintained. Independent clusters are simpler to run and cheaper to reason about. |
| Document storage | Nebius Object Storage (S3-compatible) | Holds raw PDFs, extracted text, and chunks. Works with standard S3 tooling. |
| Vector search | pgvector on managed PostgreSQL, or Qdrant in-cluster | Start with one option. Both are open source. |
| Observability | kube-prometheus-stack, DCGM exporter, Grafana, Loki, OpenCost | Open source, widely supported, and covers system, GPU, and cost metrics. |
| LLM metrics | vLLM `/metrics` endpoint, MLflow for training runs | Inference latency, throughput, and token counts come from vLLM. Training loss and eval metrics go to MLflow. |

---

## Repository layout

```
.
├── README.md
├── stacks/
│   ├── 01-platform/              # HCP Terraform workspace: networking, storage, K8s, GPU pools
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf           # cloud {} block points to the HCP Terraform workspace
│   │   └── profiles/
│   │       ├── budget.md         # documented values for the budget workspace
│   │       └── multiregion.md
│   └── 02-observability/         # HCP Terraform workspace: monitoring, dashboards, cost tracking
│       ├── main.tf
│       ├── variables.tf
│       ├── versions.tf
│       ├── helm/values-*.yaml
│       └── dashboards/*.json     # Grafana dashboards as code
├── apps/
│   ├── ingest/                   # PDF → text → chunks → embeddings
│   ├── train/                    # fine-tuning jobs (Kubernetes Jobs)
│   └── rag-api/                  # retrieval + generation service
└── .github/workflows/            # optional: trigger HCP Terraform runs from CI
```

---

## HCP Terraform setup

Do this once.

1. **Create an organization** in HCP Terraform, or use an existing one.
2. **Create a project** named `spiritual-rag`. Use projects to group the workspaces and limit team access.
3. **Create two workspaces** (CLI-driven or VCS-driven; both work):

   | Workspace | Working directory | Purpose |
   |---|---|---|
   | `spiritual-rag-platform-budget` | `stacks/01-platform` | Single-region, CPU-first, GPU pool at 0 |
   | `spiritual-rag-observability` | `stacks/02-observability` | Monitoring and dashboards |

   Add a third workspace, `spiritual-rag-platform-multiregion`, only after the budget profile works.

4. **Enable remote state sharing** on `spiritual-rag-platform-budget` and allow `spiritual-rag-observability` to read it. The observability stack needs the cluster endpoint and kubeconfig from the platform stack.
5. **Add a run trigger** so `spiritual-rag-observability` runs after `spiritual-rag-platform-budget` applies successfully.
6. **Create a variable set** named `nebius-credentials` and attach it to both workspaces. Put the Nebius service account credentials there as **sensitive** variables or environment variables, following the [Nebius authentication guide](https://docs.nebius.com/terraform-provider/authentication). Do not put them in `.tf` or `.tfvars` files.
7. **Set workspace variables** for the non-secret settings listed in each stack's section below.
8. **Log in from your machine** so you can run the CLI commands in this README:

   ```bash
   terraform login
   ```

Keep the HCP Terraform API token out of git. Use `terraform login` or an environment variable.

---

## Quick start

```bash
# 1. Platform: networking, object storage, Kubernetes, GPU pool (scaled to 0 by default)
cd stacks/01-platform
terraform init
terraform plan     # queues a remote plan in spiritual-rag-platform-budget
terraform apply    # queues a remote apply; approve in the HCP Terraform UI

# 2. Fetch kubeconfig for the cluster (sensitive output, read from remote state)
terraform output -raw kubeconfig > ~/.kube/spiritual-rag.yaml
export KUBECONFIG=~/.kube/spiritual-rag.yaml

# 3. Observability runs automatically via the run trigger. To run it by hand:
cd ../02-observability
terraform init
terraform apply

# 4. Port-forward Grafana (or expose it behind an authenticated ingress)
kubectl -n monitoring port-forward svc/grafana 3000:80
```

Grafana runs at `http://localhost:3000`. Change the default admin password on first login.

---

## Stack 1: Platform

Workspace: `spiritual-rag-platform-budget`.

Creates:

- A VPC and subnets in each configured region.
- A Managed Kubernetes cluster per region. The control plane is managed.
- Node groups:
  - `system` (CPU, always on, small)
  - `cpu-workers` (CPU, for ingest and the RAG API)
  - `gpu-train` and `gpu-infer` (GPU, **min size 0** by default)
- An Object Storage bucket for `raw/` PDFs, `chunks/`, and `eval/` results.
- A container registry for the app images.
- Service accounts with least-privilege roles, one per workload.

**Workspace variables** (set in HCP Terraform, not in files):

| Variable | Budget value | Notes |
|---|---|---|
| `primary_region` | `eu-north1` | Check current GPU availability and price per region |
| `gpu_preset` | a single-GPU preset | Pick from the Nebius catalog |
| `gpu_min_size` | `0` | Scale-to-zero default |
| `gpu_max_size` | `1` | Hard cap on GPU nodes |
| `enable_secondary_region` | `false` | Keep `false` until the budget profile works |

Variable names are illustrative. Confirm resource argument names against the [provider reference](https://docs.nebius.com/terraform-provider/reference/index) before applying.

Because remote runs do not accept `-var-file`, the profile docs in `profiles/` list the values to copy into each workspace. Use one workspace per profile instead of switching files.

### Multi-region notes

- Put the primary cluster and the GPU pools in one region. Cross-region traffic and data movement add cost and latency.
- The secondary region runs the stateless RAG API on CPU nodes. Reads come from a replicated vector store, and GitOps keeps both clusters on the same manifests.
- Write paths (ingest, training) run only in the primary region.

---

## Stack 2: Observability

Workspace: `spiritual-rag-observability`.

Installs into each cluster:

| Component | Purpose |
|---|---|
| `kube-prometheus-stack` | Prometheus, Alertmanager, Grafana, node and kube-state exporters |
| `dcgm-exporter` | Per-GPU utilization, memory, temperature, power, and XID errors |
| `loki` + `promtail` | Logs from training and inference pods |
| `OpenCost` | Cost allocation per namespace, workload, and label |
| Grafana dashboards (as code) | System, GPU, training, inference, and cost views |

This stack reads the cluster endpoint and kubeconfig from `spiritual-rag-platform-budget` through remote state. It needs no separate credentials for the cluster.

### Dashboards

| Dashboard | Key panels |
|---|---|
| **System** | CPU, memory, disk, network per node and per pod; pod restarts; node pressure |
| **GPU** | Utilization, framebuffer use, temperature, power draw, idle GPU-hours |
| **Training** | Loss, eval score, tokens/sec, steps/sec, checkpoint age, job status (from MLflow metrics or pushed via Pushgateway) |
| **Inference** | Request rate, p50/p95/p99 latency, time-to-first-token, tokens/sec, queue depth, KV-cache use (from vLLM `/metrics`) |
| **RAG quality** | Retrieval hit rate, chunks per query, answer latency, language mix of queries, fallback rate |
| **Cost** | Spend per namespace, GPU-hours today and this month, projected month-end spend against the USD 100 budget |

### Alerts (starter set)

- GPU idle for more than 30 minutes while a GPU pool is running. This is the most common source of wasted budget.
- Projected monthly spend above 80% of budget.
- Inference p95 latency above your SLO for 10 minutes.
- Training job stuck: no step progress for 15 minutes.
- Object storage or vector store disk above 80%.

---

## Data pipeline (PDF to RAG)

1. **Ingest** (`apps/ingest`, CPU pool). Upload PDFs to `raw/<lang>/<tradition>/<work>.pdf`. Extract text with a PDF library. Use OCR (for example, Tesseract with the right language packs) for scanned pages. Non-Latin scripts need explicit language packs.
2. **Normalize.** Store Unicode as UTF-8 NFC. Keep page numbers, chapter and verse references, and the source language as metadata.
3. **Chunk.** Chunk by section or verse, not by fixed characters, so citations stay meaningful. Keep a parallel-translation link when a text has translations.
4. **Embed and index.** Use a multilingual embedding model. Store vectors in pgvector or Qdrant with the metadata above.
5. **Train or tune** (`apps/train`, GPU pool, scaled up only for the run). Start with retrieval tuning and prompt design before any fine-tuning. Fine-tuning is the most expensive step and the least likely to be needed.
6. **Serve** (`apps/rag-api`). Retrieve, rerank, then generate with citations back to the source passage.
7. **Evaluate** with a held-out set of question and answer pairs in each language. Track results in MLflow.

> **Content note:** Religious texts vary by tradition, translation, and edition. Record the edition and translator for every chunk. Answers should cite the passage, and the system prompt should tell the model to say when a source does not cover a question.

---

## Monitoring

Open the Grafana **Cost** dashboard before starting any GPU job. Confirm three things:

1. The GPU pool has `gpu_min_size = 0` or a planned stop time.
2. The projected spend for the run fits the remaining budget.
3. An alert exists for idle GPUs.

For the inference service, expose vLLM's `/metrics` to Prometheus with a `ServiceMonitor`. Scrape DCGM for GPU health. Push training metrics from MLflow or a Pushgateway.

---

## Cost controls

### Nebius (the USD 100 budget)

Nebius pricing changes, and GPU prices are the main driver. Check the current [Nebius pricing page](https://nebius.com/prices) before each apply. Third-party trackers report on-demand H100 pricing around USD 3.85 to 4.50 per GPU-hour, with preemptible pricing around USD 2.15. Nebius raised on-demand GPU prices effective October 1, 2026, so verify these numbers yourself.

**What USD 100 buys at those rates (GPU only):**

| GPU type | Approx. hours at USD 4.50/h (on-demand) | Approx. hours at USD 2.15/h (preemptible) |
|---|---|---|
| 1x H100 | ~22 h | ~46 h |

Storage, egress, and CPU nodes also count. Treat the table as a ceiling, not a plan.

**Budget plan**

| Item | Allocation | Notes |
|---|---|---|
| GPU training runs | USD 40 | Short runs only. Use preemptible capacity if your checkpoints are frequent. |
| GPU inference demo | USD 20 | Start the pool, run the demo, stop it. |
| CPU nodes and control planes | USD 15 | Keep the cluster small. Leave the secondary region off. |
| Object storage and vector DB | USD 10 | PDFs are small. Track `chunks/` and `eval/` growth. |
| Egress and registry | USD 5 | Pull images from inside the region where possible. |
| Reserve | USD 10 | Do not spend this. It covers surprises. |

**Rules**

1. **Single region** until the pipeline works. The `multiregion` workspace roughly doubles the baseline cost.
2. **GPU pools default to 0 nodes.** Scale up only for a run. End each job with a Kubernetes `Job` that has `ttlSecondsAfterFinished`, and scale the pool back to 0 afterward.
3. **Use CPU for development.** Chunking, embedding small corpora, and testing the API do not need a GPU.
4. **Prefer preemptible GPU capacity** for training jobs with checkpoints. Checkpoint every few minutes.
5. **Cap GPU nodes in the workspace.** Keep `gpu_max_size` low. Change it only for a planned run, and set it back to `0` afterward.
6. **Check spend daily.** Use the Cost dashboard. If your Nebius billing console offers budget alerts, enable them at USD 50 and USD 80. If it does not, rely on the projected-spend alert above.
7. **Use managed inference only if it is cheaper** than running your own GPU pool for your query volume. Compare per 1,000 requests before choosing.

### HCP Terraform (separate from the Nebius budget)

HCP Terraform bills per **managed resource** (each resource with `mode = "managed"` in state). The Free tier includes 500 managed resources at no charge. Above that, a per-resource monthly rate applies.

- Keep the budget profile well under 500 resources. Node pools, subnets, and buckets each count as one resource. Helm releases and Kubernetes manifests managed by Terraform each count too.
- Manage Kubernetes manifests with Argo CD, not Terraform, to keep the Terraform resource count low.
- Check the **Usage** page in HCP Terraform each month. Plan and pricing details differ between sources, so confirm the current terms in your organization's plan settings.
- Cost estimation in plan output depends on your plan and on Nebius provider support. Confirm it in your organization's settings before relying on it.

---

## Security notes

- Use a Nebius service account for HCP Terraform. Grant only the roles it needs.
- Store Nebius credentials in a sensitive HCP Terraform variable set, not in code or `tfvars`.
- Mark outputs that contain secrets as `sensitive` (kubeconfig, registry credentials). Remote state still stores them, so limit who can read the workspace.
- Limit workspace and project access to the people who need it.
- Keep the Object Storage bucket private. Use presigned URLs for uploads.
- Restrict Grafana and Prometheus to your own network or an authenticated ingress. Do not expose them publicly.
- Religious and personal documents may contain private material. Do not put personal data in logs, traces, or prompts.

---

## Teardown

Destroy in reverse order to stop all billing. Use the HCP Terraform UI or the CLI:

```bash
cd stacks/02-observability && terraform destroy
cd ../01-platform          && terraform destroy
```

Confirm in the Nebius console that no GPU instances, load balancers, or unattached disks remain. Object Storage buckets with data are not removed by `destroy` unless you configure it to be. Check them separately.

---

## Roadmap

- [ ] HCP Terraform: project, workspaces, variable set, run trigger
- [ ] Stack 1: single-region budget profile
- [ ] Stack 2: kube-prometheus-stack, DCGM, Grafana dashboards as code
- [ ] Ingest pipeline for PDFs with OCR and multilingual normalization
- [ ] RAG API with citations
- [ ] Evaluation set per language and tradition
- [ ] Cost guardrails: scheduled scale-to-zero and budget alerts
- [ ] Optional: second region for the RAG API (`multiregion` workspace)
- [ ] Optional: Karmada for cross-cluster scheduling

---

## License

Choose a license before publishing. Apache-2.0 or MIT are common choices for infrastructure code.