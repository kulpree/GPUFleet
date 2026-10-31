# Component: kube-prometheus-stack

**Terraform:** `helm_release.kube_prometheus_stack` in `main.tf`
**Values:** `helm/values-kube-prometheus-stack.yaml`
**Chart:** https://github.com/prometheus-community/helm-charts

## What it is

A bundle of Helm charts that installs:

- **Prometheus**: scrapes metrics over HTTP, stores them, and evaluates alert rules.
- **Prometheus Operator**: lets you declare scrape targets (`ServiceMonitor`) and alert rules (`PrometheusRule`) as Kubernetes objects.
- **Alertmanager**: groups and routes alerts. Routing is not configured in this repo yet.
- **Grafana**: dashboards. Its Grafana sidecar loads dashboards from ConfigMaps.
- **Node exporter** and **kube-state-metrics**: CPU, memory, disk, and network per node; object state per Kubernetes resource.

## Why it is here

It is the standard open-source base for Kubernetes monitoring. Every other component in this stack either ships metrics into Prometheus or reads from it.

## Settings that matter for this project

| Setting | Value | Why |
|---|---|---|
| `prometheus.prometheusSpec.retention` | `15d` (variable) | Shorter retention means less disk. |
| `prometheusSpec.storageSpec` | `{}` | No persistent volume in the budget profile. Metrics reset on restart. Add a PVC for longer history. |
| `serviceMonitorSelectorNilUsesHelmValues: false` | Enabled | Prometheus scrapes ServiceMonitors in any namespace, such as `rag` for vLLM. |
| `scrapeInterval` | `30s` | Good resolution for GPU and inference metrics without high cardinality. |
| `kubeEtcd.enabled: false` | Disabled | The managed control plane does not expose etcd to scrape. |
| `kubeControllerManager`, `kubeScheduler` | Disabled | Same reason: they are managed by Nebius. |
| `grafana.persistence.enabled` | `false` | Dashboards come from ConfigMaps, so no volume is needed. |
| `grafana.adminPassword` | Set by Terraform (`set_sensitive`) | Keeps the password out of the values file. |

## Operating it

```bash
kubectl -n monitoring get pods
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# Prometheus UI at http://localhost:9090 -> Status -> Targets to see what is scraped
```

If a target shows `DOWN`, check the ServiceMonitor's `selector` and its `release` label. The rule in this repo selects by label `release: kube-prometheus-stack`.

## Known limits

- Without persistence, a Prometheus restart loses history. Acceptable for dashboards; not acceptable for audit.
- Alertmanager has no receivers configured. Alerts show in the Prometheus and Grafana UIs only until you add one.

## References

- Chart: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
- Prometheus documentation: https://prometheus.io/docs/
- Prometheus Operator, ServiceMonitor: https://prometheus-operator.dev/docs/developer/getting-started/
- Grafana Helm chart configuration: https://github.com/grafana/helm-charts/tree/main/charts/grafana
