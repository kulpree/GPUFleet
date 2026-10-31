# Component: Loki and Promtail (logs)

**Terraform:** `helm_release.loki`, `helm_release.promtail` in `main.tf`
**Values:** `helm/values-loki.yaml`, `helm/values-promtail.yaml`
**Project:** https://grafana.com/oss/loki/

## What they are

- **Loki** stores logs and indexes only their labels, which makes it cheap compared with full-text log systems.
- **Promtail** runs on every node, reads container logs, adds Kubernetes labels (namespace, pod, container), and ships them to Loki.

## Why they are here

Training and inference fail in ways metrics do not show: a tokenizer error, a CUDA out-of-memory message, a bad checkpoint path. Logs answer those questions. Grafana queries Loki in the same dashboards as Prometheus.

## Settings for the budget profile

| Setting | Value | Reason |
|---|---|---|
| Deployment mode | `SingleBinary` | One pod, enough for this volume. Microservices mode costs more. |
| Storage | `filesystem` | No object store to pay for. Logs live on the pod's disk. |
| Persistence | Off | Logs are lost when the pod restarts. Turn it on if you need history. |
| Retention | `loki_retention_hours` (default 168 h, 7 days) | Limits growth. |
| Replicas | 1 | Single binary. |
| Promtail tolerations | GPU taint | Logs from GPU training pods are collected. |

## Querying logs

This repo does not provision the Loki data source in Grafana. Add it once in the Grafana UI (Connections > Data sources > Loki) with the URL `http://loki.monitoring.svc:3100`. To make it permanent, add a `datasources` entry to the Grafana values in `helm/values-kube-prometheus-stack.yaml`. Example LogQL:

```logql
{namespace="rag", app_kubernetes_io_name="lora-train"} |= "Error"
```

## Verify

```bash
kubectl -n monitoring get pods -l app.kubernetes.io/name=loki
kubectl -n monitoring get pods -l app.kubernetes.io/name=promtail -o wide
```

## Known limits

- Single-binary Loki with filesystem storage is not built for high volume or many users. Move to object storage and a scalable mode if logs grow.
- Verify that the Loki Helm chart in your pinned version accepts the values in `helm/values-loki.yaml`. The chart schema changes between releases.

## References

- Loki Helm chart: https://github.com/grafana/loki/tree/main/production/helm/loki
- Promtail configuration: https://grafana.com/docs/loki/latest/send-data/promtail/
- LogQL: https://grafana.com/docs/loki/latest/query/
