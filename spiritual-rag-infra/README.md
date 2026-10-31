# Spiritual RAG on Nebius

Infrastructure and code for a retrieval-augmented generation (RAG) model over a multilingual corpus of religious and spiritual texts. It runs on a managed Kubernetes cluster on [Nebius AI Cloud](https://nebius.com), is provisioned with Terraform on [HCP Terraform](https://developer.hashicorp.com/terraform/cloud-docs), and is monitored with open-source tools.

> **Budget:** designed for **USD 100 total spend on Nebius**. GPU time is the main cost, so GPU nodes scale to zero by default. Read [Cost](#cost) before you apply anything.

## What's in this repo

| Path | What it is | Start here |
|---|---|---|
| [`stacks/01-platform`](stacks/01-platform) | Terraform stack: Kubernetes cluster, CPU and GPU node groups, storage bucket, container registry, service account | [Stack README](stacks/01-platform/README.md) |
| [`stacks/02-observability`](stacks/02-observability) | Terraform stack: Prometheus, Grafana, DCGM GPU metrics, Loki logs, OpenCost, Pushgateway, dashboards, alerts | [Stack README](stacks/02-observability/README.md) |
| [`apps/`](apps) | PDF ingestion, RAG API, LoRA training job, Kubernetes manifests for vLLM and the RAG API | [Apps README](apps/README.md) |
| [`REFERENCES.md`](REFERENCES.md) | Every external source used, with notes on what was checked | [References](REFERENCES.md) |

Each component has its own page in `docs/` inside its stack, explaining what it is, why it is here, its settings, how to operate it, and its limits.

## Architecture

```
PDFs ──► apps/ingest ──► Object Storage (chunks/)
                              │
                              ▼
 pgvector ◄── embeddings ── apps/train (LoRA, GPU, optional)
    │                          │
    ▼                          ▼
 apps/rag-api ───────► vLLM inference (GPU)
    │                          │
    └────── metrics ───────────┘
                │
   Prometheus · DCGM · Loki · OpenCost · Pushgateway
                │
              Grafana dashboards and alerts

Managed Kubernetes on Nebius:  CPU node group (always-on add-ons, API, ingest)
                               GPU node group (scales 0 → 1, tainted)
Provisioned by: stacks/01-platform (state in HCP Terraform, runs local)
                stacks/02-observability (state in HCP Terraform, runs local)
```

## Prerequisites

- A Nebius AI Cloud account with billing enabled, a project, and a subnet.
- Terraform 1.6 or later, `kubectl`, `helm`, the Nebius CLI (`nebius`), and `jq`.
- An HCP Terraform organization with two workspaces (setup below).
- Python 3.10 or later and Docker, for the application code.

## HCP Terraform setup

1. Create an organization and a project named `spiritual-rag`.
2. Create two workspaces: `spiritual-rag-platform-budget` and `spiritual-rag-observability`.
3. In each workspace, set **Execution Mode** to **Local**. This keeps the Nebius key file on your computer. See [execution-and-state.md](stacks/01-platform/docs/execution-and-state.md).
4. Replace `YOUR_HCP_ORG` in both `versions.tf` files.
5. Run `terraform login`.

## Quick start

```bash
# 1. Set up Nebius credentials for Terraform (see service-accounts.md)
export NEBIUS_SA_ID=...
export NEBIUS_PUBLIC_KEY_ID=...
export NEBIUS_PRIVATE_KEY_FILE=$HOME/.nebius/authkey/private.pem

# 2. Platform
cd stacks/01-platform
cp terraform.tfvars.example terraform.tfvars   # edit values
terraform init && terraform apply

# 3. Kubeconfig
nebius mk8s cluster get-credentials --id "$(terraform output -raw cluster_id)" --external \
  --kubeconfig ~/.kube/spiritual-rag.yaml
export KUBECONFIG=~/.kube/spiritual-rag.yaml

# 4. Observability
cd ../02-observability
cp terraform.tfvars.example terraform.tfvars   # set kube_context
export TF_VAR_grafana_admin_password='choose-a-strong-password'
terraform init && terraform apply

# 5. Open Grafana
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

## Cost

| Item | Guardrail |
|---|---|
| GPU nodes | `gpu_min_size = 0`; hard cap `budget_gpu_node_cap = 1`; preemptible by default |
| Cluster | One region; `etcd_cluster_size = 1` in the budget profile |
| Logs and metrics | No persistent volumes; 7-day log retention; 15-day metric retention |
| Alerts | Idle GPU, run-rate over budget, nodes with no pods |
| HCP Terraform | Resource count kept well below the Free tier's 500 managed resources |

GPU prices change. Third-party trackers reported H100 on-demand around USD 4.50 per GPU-hour from October 2026, so USD 100 buys about 22 GPU-hours on-demand. Check the [Nebius pricing page](https://nebius.com/prices) first. Details are in [cost-guardrails.md](stacks/01-platform/docs/cost-guardrails.md).

## Before you apply: items to verify

Nothing in this repo has been run against a live Nebius account. Before the first apply:

- Replace the `VERIFY` values in `stacks/01-platform/variables.tf` (CPU and GPU platform and preset names).
- Confirm the taint attribute shape and the node group parent in `main.tf`.
- Confirm the S3 endpoint and bucket access steps in [object-storage.md](stacks/01-platform/docs/object-storage.md).
- Pin the Helm chart versions in `stacks/02-observability/terraform.tfvars`.
- Run `terraform validate` in each stack. Terraform and Helm were not available in the environment that created these files.

## Multi-region

The earlier design had a second region for the RAG API. It is **not** implemented in code yet. Terraform provider aliases and the regional selection in the Nebius provider need checking before adding it. Until then, the budget profile is single-region.

## Security

- No secrets in Git. Keys stay in local environment variables; the Grafana password is set with `TF_VAR_grafana_admin_password`.
- The Kubernetes API is limited to `admin_cidrs`. `0.0.0.0/0` is rejected by a validation.
- Workloads use their own service account. See [service-accounts.md](stacks/01-platform/docs/service-accounts.md).
- Religious and personal documents may contain private material. Keep personal data out of logs, traces, and prompts.

## Teardown

```bash
cd stacks/02-observability && terraform destroy
cd ../01-platform          && terraform destroy
```

Empty the Object Storage bucket first if you want it removed. Check the Nebius console for leftover disks or load balancers.

## License

Not chosen yet. Apache-2.0 and MIT are common for infrastructure code.
