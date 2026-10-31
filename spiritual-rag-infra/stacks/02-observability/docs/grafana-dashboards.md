# Component: Grafana dashboards as code

**Terraform:** `kubernetes_config_map_v1.dashboards` in `main.tf`
**Files:** `dashboards/*.json`
**Grafana:** installed by kube-prometheus-stack

## How it works

Each `*.json` file in `dashboards/` becomes a ConfigMap. The ConfigMap carries the label `grafana_dashboard: "1"`. The Grafana sidecar that ships with kube-prometheus-stack watches for that label and loads the dashboard. Adding a file and applying is enough to add a dashboard. Removing one and applying removes it.

The `for_each` uses `fileset`, so Terraform discovers the files on each plan.

## The four dashboards

| File | Title | Purpose | Main panels |
|---|---|---|---|
| `system-gpu.json` | Spiritual RAG - System and GPU | Health of nodes and GPUs | GPU utilization, GPU memory, GPU temperature and power, node CPU and memory |
| `inference-vllm.json` | Spiritual RAG - Inference (vLLM) | Serving quality and speed | Latency p50/p95/p99, time to first token, requests per second, tokens per second, queue depth, KV cache usage |
| `training.json` | Spiritual RAG - Training | Training progress | Loss by run, eval score by run and language, throughput, step counter, seconds since last checkpoint |
| `cost-budget.json` | Spiritual RAG - Cost and Budget | Spending against USD 100 | Cost rate, projected monthly run-rate, GPU nodes running, budget percent, cost by node and namespace |

## Data sources

All panels read from the Prometheus data source. The panels set `"datasource": {"uid": "prometheus"}`. kube-prometheus-stack names its default Prometheus data source `prometheus`. If your Grafana uses a different UID, change it in the JSON or in Grafana's data-source settings.

## Editing a dashboard

1. Edit in the Grafana UI and export the JSON (Share > Export > Save to file).
2. Replace the file in `dashboards/`, keeping the `uid` the same so links keep working.
3. Run `terraform apply` in the observability stack.

Editing in the UI without exporting means the change is lost on the next apply. Treat the Git copy as the source of truth.

## Metrics the training dashboard needs

`training.json` reads `srag_*` metrics pushed by `apps/train/train.py`. Until a training run has pushed metrics, those panels are empty. That is expected.

`srag_eval_score` is not emitted by the training script in this repo. Add it to your evaluation job with the `lang` label, or remove the panel.

## Known limits

- The dashboards use only metrics this repo documents. If a metric name changes between exporter or vLLM versions, the panel shows "no data". Check the name in Prometheus first.
- Panels are not provisioned with alert thresholds beyond the cost and percentage thresholds.

## References

- Grafana dashboard JSON model: https://grafana.com/docs/grafana/latest/dashboards/json-model/
- Grafana sidecar in kube-prometheus-stack: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
- Grafana provisioning: https://grafana.com/docs/grafana/latest/administration/provisioning/
