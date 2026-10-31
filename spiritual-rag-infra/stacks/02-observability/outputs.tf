output "namespace" {
  description = "Monitoring namespace."
  value       = kubernetes_namespace_v1.monitoring.metadata[0].name
}

output "grafana_access" {
  description = "How to open Grafana locally."
  value       = "kubectl -n ${var.namespace} port-forward svc/kube-prometheus-stack-grafana 3000:80  # then open http://localhost:3000"
}

output "prometheus_access" {
  description = "How to open Prometheus locally."
  value       = "kubectl -n ${var.namespace} port-forward svc/kube-prometheus-stack-prometheus 9090:9090  # then open http://localhost:9090"
}

output "pushgateway_url" {
  description = "In-cluster URL that training jobs use to push metrics."
  value       = "http://prometheus-pushgateway.${var.namespace}.svc:9091"
}

output "dashboards" {
  description = "Grafana dashboards deployed by this stack."
  value       = keys(kubernetes_config_map_v1.dashboards)
}
