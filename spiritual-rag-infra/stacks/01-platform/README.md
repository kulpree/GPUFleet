# Stack 01: Platform

Provisions the Nebius infrastructure the RAG system runs on: a managed Kubernetes cluster, CPU and GPU node groups, an Object Storage bucket for the corpus, a container registry, and a service account for workloads.

**HCP Terraform workspace:** `spiritual-rag-platform-budget`
**Applies before:** `02-observability` (which needs the cluster and its kubeconfig)

## What it creates

| Resource | Terraform type | Component doc |
|---|---|---|
| Kubernetes control plane | `nebius_mk8s_v1_cluster.primary` | [docs/kubernetes-cluster.md](docs/kubernetes-cluster.md) |
| CPU node group | `nebius_mk8s_v1_node_group.cpu` | [docs/cpu-node-group.md](docs/cpu-node-group.md) |
| GPU node group (scales to 0) | `nebius_mk8s_v1_node_group.gpu` | [docs/gpu-node-group.md](docs/gpu-node-group.md) |
| Object Storage bucket | `nebius_storage_v1_bucket.corpus` | [docs/object-storage.md](docs/object-storage.md) |
| Container registry | `nebius_registry_v1_registry.apps` | [docs/container-registry.md](docs/container-registry.md) |
| Workload service account | `nebius_iam_v1_service_account.workloads` | [docs/service-accounts.md](docs/service-accounts.md) |
| Budget guardrails (variables and validations) | `variables.tf` | [docs/cost-guardrails.md](docs/cost-guardrails.md) |
| Execution and state model | `versions.tf`, `providers.tf` | [docs/execution-and-state.md](docs/execution-and-state.md) |

## Files

```
01-platform/
├── versions.tf               HCP Terraform cloud{} block and provider pins
├── providers.tf              Nebius provider auth (environment variables only)
├── variables.tf              inputs, with validations for budget and security
├── main.tf                   all resources
├── outputs.tf                values the observability stack and humans need
├── terraform.tfvars.example  copy to terraform.tfvars for local runs
└── docs/                     one file per component
```

## Run it

Prerequisites: [execution-and-state.md](docs/execution-and-state.md) (workspace in Local mode, login, credentials).

```bash
cd stacks/01-platform
cp terraform.tfvars.example terraform.tfvars   # then edit it
terraform init
terraform plan
terraform apply

# Add the cluster to kubeconfig (command also in: terraform output kubeconfig_command)
nebius mk8s cluster get-credentials --id "$(terraform output -raw cluster_id)" --external \
  --kubeconfig ~/.kube/spiritual-rag.yaml
kubectl --kubeconfig ~/.kube/spiritual-rag.yaml get nodes
```

## Before the first apply

Three values are marked `VERIFY` in `variables.tf` and must be checked against the Nebius catalog: `cpu_platform`, `cpu_preset`, `gpu_platform`, and `gpu_preset`. Also check that `subnet_id` belongs to the project and region you chose.

## Destroy

```bash
terraform destroy
```

Object Storage buckets with data are not removed unless you empty them first. Check the Nebius console afterward for leftover disks or load balancers.
