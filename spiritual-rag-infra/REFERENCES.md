# References

Each entry says how it was used and whether it was checked during this work.

- **Checked** means the page was read in this work session.
- **From memory** means it is a well-known project or path, but the page was not read. Verify before relying on exact names or flags.

## Nebius AI Cloud

| Topic | Link | Status | Used for |
|---|---|---|---|
| Terraform provider overview | https://docs.nebius.com/terraform-provider | Checked | Provider purpose and resources |
| Terraform quickstart | https://docs.nebius.com/terraform-provider/quickstart | Checked | Service account and registry example |
| Terraform authentication | https://docs.nebius.com/terraform-provider/authentication | Checked | Service account auth; user-token caveat |
| Provider configuration | https://docs.nebius.com/terraform-provider/reference/provider | Checked | `service_account` block and `*_env` options |
| Resource reference index | https://docs.nebius.com/terraform-provider/reference/index | Checked | Resource names: `nebius_mk8s_v1_cluster`, `nebius_mk8s_v1_node_group`, `nebius_vpc_v1_subnet`, `nebius_storage_v1_bucket`, `nebius_registry_v1_registry`, `nebius_iam_v1_service_account`, `nebius_iam_v1_access_permit` |
| Node group resource | https://docs.nebius.com/terraform-provider/reference/resources/mk8s_v1_node_group | Checked | `parent_id`, `template`, `autoscaling`, `gpu_settings`, `preemptible` |
| Managed Kubernetes cluster (how to) | https://docs.nebius.com/kubernetes/clusters/manage | Checked | `public_endpoint`, `subnet_id`, `etcd_cluster_size` |
| Cluster `get-credentials` CLI | https://docs.nebius.com/cli/reference/mk8s/cluster/get-credentials | Checked | Kubeconfig command |
| Node group CLI (GPU settings, taints, preemptible) | https://docs.nebius.com/cli/reference/mk8s/v1alpha1/node-group/create | Checked (v1alpha1, deprecated); v1 options from the reference | GPU driver preset and taints |
| Authorized keys for service accounts | https://docs.nebius.com/iam/service-accounts/authorized-keys | Checked | Key creation for Terraform |
| Terraform provider releases | https://github.com/nebius/terraform-provider-nebius/releases | Checked | v0.6.16 changes, including `allowed_cidrs` |
| Managed Kubernetes operations | https://nebius.ai/docs/managed-kubernetes/operations/connect | Checked | Internal and external endpoint options |
| Pricing | https://nebius.com/prices | From memory (price page cited by third parties) | GPU hourly rates |
| Pricing commentary (third party) | https://fourweekmba.com/ai-nebius-lifts-on-demand-gpu-prices-up-to-21-from-1-october/ | Checked (secondary source) | H100 at USD 4.50 per GPU-hour from October 1, 2026 |
| Pricing commentary (third party) | https://select.keenable.ai/r/real-h100-cloud-cost-compute-discounts-egress-availability/zIIR2YalYLMWP0wK4wbdmw | Checked (secondary source) | Preemptible H100 at USD 2.15 per GPU-hour |
| Managed Kubernetes with Seqera (case study) | https://seqera.io/blog/deploying-gpu-accelerated-nextflow-pipelines-on-nebius-kubernetes-with-seqera/ | Checked (secondary source) | Managed control plane at no cost; worker nodes billed while running; GPU nodes with preinstalled drivers |
| Object Storage (S3-compatible) | https://docs.nebius.com/storage | From memory; path unverified | Bucket use and endpoint |
| Storing Terraform state in a bucket | https://docs.nebius.com/terraform-provider/ | Checked (page title only) | Option, not used |

## HashiCorp HCP Terraform

| Topic | Link | Status | Used for |
|---|---|---|---|
| Terraform CLI integration (`cloud` block) | https://developer.hashicorp.com/terraform/cli/cloud | From memory | `cloud {}` block and login |
| Estimate HCP Terraform cost (managed resources) | https://developer.hashicorp.com/terraform/cloud-docs/overview/estimate-hcp-terraform-cost | Checked | 500 free managed resources; per-resource pricing |
| Estimate cost (usage report) | https://developer.hashicorp.com/terraform/cloud-docs/overview/estimate-cost | Checked | Usage page |
| Free tier migration | https://www.hashicorp.com/blog/continuing-hcp-terraform-s-enhanced-free-tier-experience | Checked | Free tier includes 500 managed resources |
| Third-party tier summary | https://scalr.com/learning-center/terraform-cloud-pricing-changes | Checked (secondary source, conflicts with the official page on tiers) | Noted as conflicting; not relied on |
| Terraform `helm` provider | https://registry.terraform.io/providers/hashicorp/helm/latest/docs | From memory | Provider v3 `kubernetes = {}` attribute syntax |
| Terraform `kubernetes` provider | https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs | From memory | Namespace and ConfigMap resources |
| Terraform variable validation | https://developer.hashicorp.com/terraform/language/values/variables#custom-validation-rules | From memory | Budget and security validations |

## Kubernetes and monitoring

| Topic | Link | Status | Used for |
|---|---|---|---|
| kube-prometheus-stack chart | https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack | From memory | Prometheus, Grafana, Alertmanager; values keys |
| Prometheus documentation | https://prometheus.io/docs/ | From memory | Alerting rules, PromQL |
| Prometheus Operator | https://prometheus-operator.dev/docs/developer/getting-started/ | From memory | ServiceMonitor and PrometheusRule |
| Prometheus, when to use Pushgateway | https://prometheus.io/docs/practices/pushing/ | From memory | Batch job metrics |
| Pushgateway project | https://github.com/prometheus/pushgateway | From memory | Gateway service and API |
| DCGM exporter | https://github.com/NVIDIA/dcgm-exporter | From memory | GPU metrics, Helm chart `dcgm-exporter` |
| NVIDIA DCGM field reference | https://docs.nvidia.com/datacenter/dcgm/latest/dev-guide/dcgm-diag.html | From memory; the link is a general page, not the field table | DCGM metric meanings |
| Loki | https://grafana.com/docs/loki/latest/ | From memory | Single-binary mode, LogQL |
| Loki Helm chart | https://github.com/grafana/loki/tree/main/production/helm/loki | From memory | Chart values |
| OpenCost | https://www.opencost.io/docs/ | From memory | Cost allocation and custom pricing |
| OpenCost Helm chart | https://github.com/opencost/opencost-helm-chart | From memory | Chart values |
| Kubernetes taints and tolerations | https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ | From memory | GPU taint |
| Kubernetes node selectors | https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ | From memory | `nodeSelector` on pools |
| Kubernetes Jobs TTL | https://kubernetes.io/docs/concepts/workloads/controllers/ttlafterfinished/ | From memory | `ttlSecondsAfterFinished` |
| NVIDIA device plugin for Kubernetes | https://github.com/NVIDIA/k8s-device-plugin | From memory | `nvidia.com/gpu` resource |
| Grafana dashboard JSON model | https://grafana.com/docs/grafana/latest/dashboards/json-model/ | From memory | Dashboard file format |
| Grafana provisioning | https://grafana.com/docs/grafana/latest/administration/provisioning/ | From memory | Data sources |

## AI and RAG

| Topic | Link | Status | Used for |
|---|---|---|---|
| vLLM OpenAI-compatible server | https://docs.vllm.ai/en/latest/serving/openai_compatible_server.html | From memory | Inference server and `/v1/chat/completions` |
| vLLM metrics | https://docs.vllm.ai/en/latest/serving/metrics.html | From memory | Metric names used in dashboards (`vllm:*`); confirm for your version |
| Qwen2.5 7B Instruct | https://huggingface.co/Qwen/Qwen2.5-7B-Instruct | From memory | Example base model; check the license |
| Multilingual E5 embeddings | https://huggingface.co/intfloat/multilingual-e5-base | From memory | Embedding model; `query:` prefix convention |
| pgvector | https://github.com/pgvector/pgvector | From memory | `<=>` distance operator and `vector` type |
| PEFT (LoRA) | https://huggingface.co/docs/peft | From memory | `LoraConfig`, `get_peft_model` |
| Transformers Trainer | https://huggingface.co/docs/transformers/main_classes/trainer | From memory | Training loop and callbacks |
| pypdf | https://pypdf.readthedocs.io/ | From memory | `PdfReader` text extraction |
| FastAPI | https://fastapi.tiangolo.com/ | From memory | Routes and validation |
| psycopg | https://www.psycopg.org/psycopg3/docs/ | From memory | Connections and queries |
| prometheus_client (Python) | https://github.com/prometheus/client_python | From memory | Gauges, counters, histograms, `push_to_gateway` |

## Architecture decisions

| Topic | Link | Status | Used for |
|---|---|---|---|
| KubeFed (not used) | https://github.com/kubernetes-sigs/kubefed | From memory (reported as no longer actively maintained) | Why federation is not used |
| Karmada (optional future) | https://karmada.io/ | From memory | Multi-cluster scheduling option |
| Argo CD ApplicationSet (optional future) | https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/ | From memory | GitOps across clusters |
