# 📖 Scripture RAG Platform on Nebius

> A fully-declarative, cost-capped, observability-first **Retrieval-Augmented Generation (RAG)** platform for querying spiritual scriptures across multiple PDF files — deployed on **Nebius Managed Kubernetes (MK8s)** with **Terraform** and **Open-Source Monitoring**.

---

## 📑 Table of Contents

1. [What This Project Delivers](#-what-this-project-delivers)
2. [Architecture](#-architecture)
3. [Prerequisites](#-prerequisites)
4. [Configuration](#-configuration)
5. [Repository Layout](#-repository-layout)
6. [Step-by-Step Setup](#-step-by-step-setup)
7. [Source Files](#-source-files)
8. [Monitoring & Dashboards](#-monitoring--dashboards)
9. [Continuity & Resilience](#-continuity--resilience)
10. [Cost Management](#-cost-management)
11. [Troubleshooting](#-troubleshooting)
12. [Teardown](#-teardown)
13. [Appendix](#-appendix)

---

## 🎯 What This Project Delivers

| Capability | Implementation |
|---|---|
| **Multi-region Kubernetes** | Two MK8s clusters in separate Nebius regions (training + inference) |
| **Cost-capped GPU compute** | Spot L40S with a hard `$0.80/GPU-hr` pricing policy |
| **PDF ingestion pipeline** | CPU Job that parses, chunks, and embeds PDFs via Nebius Token Factory |
| **Vector search** | Qdrant in-cluster with persistent storage |
| **Grounded LLM answers** | vLLM serving Qwen2.5-7B-Instruct on the inference cluster |
| **Full observability** | kube-prometheus-stack + DCGM + vLLM/Qdrant ServiceMonitors |
| **Continuity & recovery** | Persistent state, snapshots, checkpointed training, auto-recovery |
| **Total budget guardrails** | Spot pricing policy + auto-teardown + per-namespace quotas |

**Total footprint:** ≈ **$4–$6 per 4-hour session**, well within a **$100 ceiling** for a proof-of-concept.

---

## 🏗️ Architecture

### High-Level View
┌──────────────────────────────────────┐
│ USER BROWSER │
└──────────────┬───────────────────────┘
│ HTTPS
┌──────────────▼───────────────────────┐
│ kubectl port-forward (or Ingress) │
└──────┬───────────────────────┬───────┘
│ │
┌────────────▼──────┐ ┌───────────▼─────────┐
│ RAG Query API │ │ Grafana Dashboard │
│ (FastAPI, CPU) │ │ (localhost:3000) │
└──┬─────────────┬──┘ └───────────┬─────────┘
│ │ │
┌───────────────▼──┐ ┌──────▼────────┐ ┌──────▼──────────┐
│ Token Factory │ │ vLLM (GPU) │ │ Prometheus │
│ Embeddings API │ │ Qwen2.5-7B │ │ (TSDB PVC) │
└──────────────────┘ └───────▲───────┘ └──────▲──────────┘
│ │
┌──────────────────┐ ┌────────┴────────┐ ┌──────┴──────────┐
│ Qdrant (CPU) │◀──│ Context (top-k)│ │ DCGM Exporter │
│ Vector DB (PVC) │ │ from retrieved │ │ node-exporter │
└────────▲─────────┘ └─────────────────┘ │ kube-state-m. │
│ └─────────────────┘
┌────────┴─────────┐
│ Ingestion Job │◀─── PDFs in Object Storage
│ (CPU, on-demand) │
└──────────────────┘


### Two-Stack Terraform Design

┌─────────────────────────────────────────────────────────────────┐
│ STACK 1 — infrastructure/ │
│ Owns: │
│ • Nebius project-scoped pricing policies │
│ • Two MK8s clusters (region A + region B) │
│ • CPU + GPU node groups per cluster │
│ Outputs: │
│ • cluster_a_id, cluster_b_id, kube contexts │
│ State: s3://tfstate-/infrastructure.tfstate │
└───────────────────────────┬─────────────────────────────────────┘
│ outputs consumed by Stack 2
┌───────────────────────────▼─────────────────────────────────────┐
│ STACK 2 — workloads/ │
│ Owns: │
│ • Namespaces: rag, monitoring │
│ • kube-prometheus-stack, DCGM Exporter │
│ • Qdrant StatefulSet + PVC │
│ • vLLM Deployment on GPU node │
│ • RAG query service (CPU) + ServiceMonitors │
│ • Ingestion Job (applied via kubectl, idempotent) │
│ State: s3://tfstate-/workloads.tfstate │
└─────────────────────────────────────────────────────────────────┘


**Why two stacks?**

- **Independence:** Destroy workloads without losing GPU nodes (useful for iterating on RAG code).
- **Faster iteration:** Changing the vLLM model or adding a dashboard takes ~2 minutes, not ~20.
- **Safe teardown:** Destroy `workloads/` first, then `infrastructure/`, avoiding orphaned Helm releases.

### What Gets Deployed

**Stack 1 — Infrastructure**

| Resource | Region | Purpose | Cost |
|---|---|---|---|
| MK8s cluster A | `eu-north1` | Training + control + monitoring | Free control plane |
| CPU node group A | `eu-north1` | Prometheus, Grafana, Qdrant, RAG API | ≈ $0.05/hr |
| GPU node group A | `eu-north1` | Ingestion / training experiments | ≈ $0.74/hr (spot L40S) |
| MK8s cluster B | `eu-west1` | Inference only | Free control plane |
| CPU node group B | `eu-west1` | RAG API replica | ≈ $0.05/hr |
| GPU node group B | `eu-west1` | vLLM | ≈ $0.74/hr (spot L40S) |
| Pricing policy A + B | Both | Hard `$0.80/GPU-hr` spot cap | Protects budget |

**Stack 2 — Workloads**

| Component | Namespace | Cluster | Node | Persistence |
|---|---|---|---|---|
| kube-prometheus-stack | `monitoring` | A | CPU | 10 GiB PVC (TSDB) |
| DCGM Exporter | `monitoring` | A + B | GPU | none |
| Qdrant | `rag` | A | CPU | 10 GiB PVC |
| vLLM (Qwen2.5-7B) | `rag` | B | GPU | HF cache PVC |
| RAG query service | `rag` | B | CPU | none |
| Ingestion Job | `rag` | A | CPU | none (idempotent) |

---

## 📋 Prerequisites

| Tool | Version | Install |
|---|---|---|
| Terraform | ≥ 1.5 | https://developer.hashicorp.com/terraform/install |
| Nebius CLI | latest | https://docs.nebius.com/cli/install |
| `kubectl` | ≥ 1.28 | https://kubernetes.io/docs/tasks/tools/ |
| `helm` | ≥ 3.14 | https://helm.sh/docs/intro/install/ |
| `aws` CLI | any | For S3-compatible Object Storage |
| `jq` | any | JSON parsing helper |

**Nebius account requirements:**

- Project with billing enabled
- IAM token (`nebius iam get-access-token`)
- Token Factory API key (embeddings)
- Minimum card deposit of **$25** (per Nebius billing policy)

---

## 🔐 Configuration

Export these in your shell (or `.env` file):

```bash
# ----- Nebius account -----
export NEBIUS_PROJECT_ID="project-e00xxxxxxxxxxxxxxxx"
export NEBIUS_IAM_TOKEN="$(nebius iam get-access-token)"
export NEBIUS_API_KEY="tf-key-xxxxxxxxxxxx"

# ----- Regions & capacity -----
export REGION_A="eu-north1"
export REGION_B="eu-west1"
export GPU_PLATFORM="gpu-l40s"
export MAX_SPOT_PRICE="0.80"

# ----- Names & budget guardrails -----
export CLUSTER_PREFIX="ai-rag"
export DURATION_HOURS="4"
export GRAFANA_ADMIN_PASSWORD="change-me-now"

# ----- Data plane -----
export CORPUS_BUCKET="scripture-corpus-$(date +%s)"
export TFSTATE_BUCKET="tfstate-${CLUSTER_PREFIX}-$(date +%s)"

# ----- Object Storage credentials -----
export AWS_ACCESS_KEY_ID="<object-storage-key>"
export AWS_SECRET_ACCESS_KEY="<object-storage-secret>"

nebius iam get-access-token >/dev/null && echo "✓ IAM OK"
aws --endpoint-url "https://storage.${REGION_A}.nebius.cloud" s3 ls >/dev/null \
  && echo "✓ Object Storage OK"
  ```


ai-rag/
├── README.md                        # this file
├── setup.sh                         # single orchestrator (all actions)
├── infrastructure/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── backend.tf
│   └── terraform.tfvars
└── workloads/
    ├── main.tf
    ├── variables.tf
    ├── backend.tf
    ├── terraform.tfvars
    ├── manifests/
    │   ├── qdrant.yaml
    │   ├── vllm.yaml
    │   ├── rag-query.yaml
    │   ├── servicemonitors.yaml
    │   ├── alerts.yaml
    │   └── ingestion-job.yaml
    ├── query_service.py
    └── ingest.py