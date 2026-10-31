# Component: OpenCost (cost allocation)

**Terraform:** `helm_release.opencost` in `main.tf`
**Values:** `helm/values-opencost.yaml`
**Project:** https://www.opencost.io/docs/

## What it is

An open-source, CNCF project that estimates the cost of each Kubernetes workload. It reads resource requests and node prices, and publishes the result as Prometheus metrics. Grafana then shows cost per namespace, node, or workload.

## Why it is here

The USD 100 budget is spent per node-hour. Knowing which node and which namespace is costing money is the first step to cutting it. OpenCost turns "the bill went up" into "the GPU node is running a job nobody needs."

## How costs are calculated

OpenCost allocates a node's hourly price to the pods on it, in proportion to CPU, memory, and GPU requests. Idle capacity is reported separately.

**Important:** OpenCost prices nodes from a price model. Its built-in models assume cloud list prices. Nebius rates differ, so the numbers are estimates until you set custom pricing. Use the Nebius bill as the source of truth.

## Setting custom prices

Set custom node prices for the Nebius CPU and GPU presets in the OpenCost configuration (the Helm values under `opencost.customPricing`). The exact key names depend on the OpenCost version, so check the OpenCost custom pricing guide before you set them. Keep the prices in a file you update when Nebius changes its rate card.

## Metrics used

| Metric | Used by |
|---|---|
| `node_total_hourly_cost` | Cost dashboard; `RunRateExceedsBudget` and `NodeCostWithoutWorkload` alerts |
| `node_cpu_hourly_cost`, `node_ram_hourly_cost`, `node_gpu_hourly_cost` | Breakdown per node |
| `container_cpu_allocation`, `container_memory_allocation_bytes` | Cost by namespace |

Confirm the exact metric names against the OpenCost version you install by querying Prometheus for `node_total_hourly_cost`.

## Settings in this repo

| Setting | Value | Reason |
|---|---|---|
| `opencost.prometheus.internal` | Points at `kube-prometheus-stack-prometheus` in `monitoring` | OpenCost reuses the stack's Prometheus. |
| `opencost.ui.enabled` | `false` | Cost views live in Grafana, so one UI is enough. |
| `defaultClusterId` | `spiritual-rag-primary` | Labels cost data with the cluster name. |

## Verify

```bash
kubectl -n monitoring get pods -l app.kubernetes.io/name=opencost
kubectl -n monitoring port-forward svc/opencost 9003:9003
curl -s localhost:9003/allocation/compute?window=7d | head
```

## Known limits

- Estimates only, until custom prices are set.
- Idle GPU cost is visible but not automatically stopped. The alert and the Terraform cap do that.

## References

- OpenCost documentation: https://www.opencost.io/docs/
- OpenCost Helm chart: https://github.com/opencost/opencost-helm-chart
- CNCF project page: https://www.cncf.io/projects/opencost/
