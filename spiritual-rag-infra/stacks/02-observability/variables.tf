variable "kubeconfig_path" {
  description = "Path to the kubeconfig written by `nebius mk8s cluster get-credentials`."
  type        = string
  default     = "~/.kube/spiritual-rag.yaml"
}

variable "kube_context" {
  description = "kubeconfig context name. The Nebius CLI sets a default; check with `kubectl config get-contexts`."
  type        = string
}

variable "namespace" {
  description = "Namespace for all monitoring components."
  type        = string
  default     = "monitoring"
}

variable "grafana_admin_password" {
  description = "Grafana admin password. Set it locally or as a sensitive workspace variable. Never commit it."
  type        = string
  sensitive   = true
}

variable "grafana_ingress_enabled" {
  description = "Grafana is reached with port-forward by default. Keep false unless you add an authenticated ingress."
  type        = bool
  default     = false
}

variable "monthly_budget_usd" {
  description = "Monthly budget used by the run-rate alert."
  type        = number
  default     = 100
}

variable "prometheus_retention" {
  description = "How long Prometheus keeps metrics. Shorter retention means less disk, which is a cost."
  type        = string
  default     = "15d"
}

variable "loki_retention_hours" {
  description = "Log retention in hours."
  type        = number
  default     = 168
}

# Chart versions. Leave null to use the latest chart, or pin the exact version
# after checking the chart repository. Pinning is recommended.
variable "kube_prometheus_stack_version" {
  type    = string
  default = null
}

variable "dcgm_exporter_version" {
  type    = string
  default = null
}

variable "loki_version" {
  type    = string
  default = null
}

variable "promtail_version" {
  type    = string
  default = null
}

variable "opencost_version" {
  type    = string
  default = null
}

variable "pushgateway_version" {
  type    = string
  default = null
}
