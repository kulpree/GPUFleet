# Stack 02: Observability

Installs open-source monitoring into the cluster from stack 01: metrics, GPU telemetry, logs, cost allocation, dashboards, and alerts. Everything is defined as code, and the dashboards are versioned JSON.

**HCP Terraform workspace:** `spiritual-rag-observability`
**Applies after:** `01-platform`

## What it installs

| Component | Helm chart | Purpose | Component doc |
|---|---|---|---|
| kube-prometheus-stack | `prometheus-community/kube-prometheus-stack` | Prometheus, Alertmanager, Grafana, node exporter | [docs/kube-prometheus-stack.md](docs/kube-prometheus-stack.md) |
| DCGM exporter | `nvidia/dcgm-exporter` | Per-GPU utilization, memory, temperature, power, XID errors | [docs/dcgm-exporter.md](docs/dcgm-exporter.md) |
| Loki and Promtail | `grafana/loki`, `grafana/promtail` | Log storage and collection from all pods | [docs/loki-promtail.md](docs/loki-promtail.md) |
| OpenCost | `opencost/opencost` | Cost allocation per namespace and workload | [docs/opencost.md](docs/opencost.md) |
| Pushgateway | `prometheus-community/prometheus-pushgateway` | Receives metrics from batch training jobs | [docs/pushgateway.md](docs/pushgateway.md) |
| Dashboards as code | ConfigMaps in `dashboards/` | Four Grafana dashboards | [docs/grafana-dashboards.md](docs/grafana-dashboards.md) |
| Alert rules | `helm/values-kube-prometheus-stack.yaml` | Starter alerts for GPU, inference, and cost | [docs/alerting.md](docs/alerting.md) |

## Files

```
02-observability/
├── versions.tf / providers.tf   HCP Terraform block; helm and kubernetes providers
├── variables.tf                 inputs, chart versions, retention, Grafana password
├── main.tf                      namespace, Helm releases, dashboard ConfigMaps
├── outputs.tf                   port-forward commands and the Pushgateway URL
├── terraform.tfvars.example
├── helm/                        values files, one per chart
├── dashboards/                  Grafana dashboards (JSON)
└── docs/                        one file per component
```

## Run it

Prerequisites: stack 01 applied, kubeconfig present, and the workspace in Local mode (see [01-platform/docs/execution-and-state.md](../01-platform/docs/execution-and-state.md)).

```bash
cd stacks/02-observability
cp terraform.tfvars.example terraform.tfvars   # set kube_context
export TF_VAR_grafana_admin_password='choose-a-strong-password'

terraform init
terraform plan
terraform apply
```

Open Grafana:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
# http://localhost:3000   user: admin   password: the value you exported
```

## Before the first apply

- **Pin chart versions** in `terraform.tfvars` once you have checked the chart repositories. Leaving them `null` installs the latest chart, which makes upgrades hard to reproduce.
- **Check the service names** in `outputs.tf`. They assume the Helm release names used in `main.tf`.
- **Set the OpenCost price model** if you want costs in USD that match Nebius rates. See [docs/opencost.md](docs/opencost.md).

## Destroy

```bash
terraform destroy
```

Dashboards are removed with the ConfigMaps. Prometheus and Loki use no persistent volumes in the budget profile, so their data is lost on destroy. That is intended.
