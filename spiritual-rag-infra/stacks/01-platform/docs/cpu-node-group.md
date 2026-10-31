# Component: CPU node group

**Terraform resource:** `nebius_mk8s_v1_node_group.cpu`

## What it is

A pool of CPU-only worker nodes. Each node is a Nebius compute instance that runs the kubelet and registers with the cluster.

## Why it is here

Most of the work in this system does not need a GPU:

- PDF extraction, OCR, chunking, and embedding of small batches (`apps/ingest`)
- The RAG API, which retrieves passages and calls the inference server (`apps/rag-api`)
- Cluster add-ons, the Prometheus stack, Loki, and OpenCost

Running these on CPU keeps the expensive GPU pool idle when nothing needs it.

## Key settings

| Argument | Value | Notes |
|---|---|---|
| `autoscaling.min_node_count` | `0` | Allows the pool to drop to zero. Add-ons need at least one node, so put a fixed system node in a separate pool if you need that. |
| `autoscaling.max_node_count` | `2` | A small ceiling limits surprise spend. |
| `template.resources.platform` | `cpu-d3` (VERIFY) | Check the catalog. |
| `template.resources.preset` | `4vcpu-16gb` (VERIFY) | Check the catalog. |
| `template.metadata.labels` | `workload: cpu` | Pods select this pool with `nodeSelector`. |

## Scheduling

CPU pods do not tolerate the GPU taint, so the scheduler will not place them on GPU nodes. The GPU node group is labelled `workload: gpu`. Workloads select the pool they need with `nodeSelector`.

## Operations

- Check node count with `kubectl get nodes -L workload`.
- A pod that stays `Pending` may mean the autoscaler has hit `max_node_count`. Raise it or delete unused workloads.
- Add-ons such as the metrics server need at least one ready node. If you set `min_node_count = 0`, expect a short delay on the first start.

## References

- Terraform resource: https://docs.nebius.com/terraform-provider/reference/resources/mk8s_v1_node_group
- Kubernetes node labels and selectors: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
