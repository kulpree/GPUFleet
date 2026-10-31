# Component: DCGM exporter (NVIDIA GPU metrics)

**Terraform:** `helm_release.dcgm_exporter` in `main.tf`
**Values:** `helm/values-dcgm-exporter.yaml`
**Project:** https://github.com/NVIDIA/dcgm-exporter

## What it is

A DaemonSet that runs on each GPU node. It reads GPU counters through NVIDIA's Data Center GPU Manager (DCGM) and exposes them as Prometheus metrics.

## Why it is here

GPU metrics are the core of the cost and health picture. The utilization metric detects idle GPUs, which is the most common way the budget gets wasted. Memory and XID errors catch failures before a job crashes.

## Metrics used in this project

| Metric | Meaning | Used by |
|---|---|---|
| `DCGM_FI_DEV_GPU_UTIL` | GPU busy percentage | GPU dashboard; `GPUIdleWhileRunning` alert; cost dashboard GPU count |
| `DCGM_FI_DEV_FB_USED` / `DCGM_FI_DEV_FB_FREE` | Framebuffer (GPU memory) used and free, MiB | GPU dashboard; `GPUMemoryNearFull` alert |
| `DCGM_FI_DEV_GPU_TEMP` | Temperature, °C | GPU dashboard |
| `DCGM_FI_DEV_POWER_USAGE` | Power draw, W | GPU dashboard |
| `DCGM_FI_DEV_XID_ERRORS` | Last XID error code | `GPUXIDError` alert |

Metric names follow the exporter's default field set. If your exporter version reports different names, check `/metrics` on a GPU node and update the dashboards and alerts.

## Scheduling

The DaemonSet tolerates the GPU taint and selects nodes labelled `workload: gpu`. It does not run on CPU nodes, so it uses no resources when the GPU pool is at zero.

## Verify

```bash
kubectl -n monitoring get pods -l app.kubernetes.io/name=dcgm-exporter -o wide
kubectl -n monitoring port-forward <dcgm-pod> 9400:9400
curl -s localhost:9400/metrics | grep DCGM_FI_DEV_GPU_UTIL
```

## Known limits

- The GPU must be visible to the NVIDIA stack on the node. If the metrics are missing, check the node's GPU driver state with the cluster's GPU diagnostics and the Nebius node image.

## References

- DCGM exporter project and Helm chart: https://github.com/NVIDIA/dcgm-exporter
- DCGM field identifiers: https://docs.nvidia.com/datacenter/dcgm/latest/dev-guide/dcgm-diag.html (VERIFY the field reference link)
- Nebius GPU node groups with preinstalled drivers, from a Nebius-hosted Seqera write-up: https://seqera.io/blog/deploying-gpu-accelerated-nextflow-pipelines-on-nebius-kubernetes-with-seqera/
