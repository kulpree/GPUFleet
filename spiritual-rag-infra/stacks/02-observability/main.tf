resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/part-of" = "spiritual-rag"
    }
  }
}

# ---------------------------------------------------------------------------
# kube-prometheus-stack: Prometheus, Alertmanager, Grafana, node and
# kube-state exporters. Alert rules live in the values file.
# ---------------------------------------------------------------------------
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.kube_prometheus_stack_version
  namespace        = kubernetes_namespace_v1.monitoring.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 900

  values = [
    file("${path.module}/helm/values-kube-prometheus-stack.yaml"),
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention = var.prometheus_retention
        }
      }
    }),
  ]

  set_sensitive = [
    {
      name  = "grafana.adminPassword"
      value = var.grafana_admin_password
    },
  ]
}

# ---------------------------------------------------------------------------
# DCGM exporter: per-GPU metrics (utilization, memory, temperature, power, XID)
# ---------------------------------------------------------------------------
resource "helm_release" "dcgm_exporter" {
  name       = "dcgm-exporter"
  repository = "https://nvidia.github.io/dcgm-exporter/helm-charts"
  chart      = "dcgm-exporter"
  version    = var.dcgm_exporter_version
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  wait       = true

  values = [file("${path.module}/helm/values-dcgm-exporter.yaml")]

  depends_on = [helm_release.kube_prometheus_stack]
}

# ---------------------------------------------------------------------------
# Loki + Promtail: logs from training and inference pods
# ---------------------------------------------------------------------------
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.loki_version
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  wait       = true

  values = [
    file("${path.module}/helm/values-loki.yaml"),
    yamlencode({
      loki = {
        limits_config = {
          retention_period = "${var.loki_retention_hours}h"
        }
      }
    }),
  ]

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = var.promtail_version
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  wait       = true

  values = [file("${path.module}/helm/values-promtail.yaml")]

  depends_on = [helm_release.loki]
}

# ---------------------------------------------------------------------------
# OpenCost: cost allocation per namespace, workload, and label
# ---------------------------------------------------------------------------
resource "helm_release" "opencost" {
  name       = "opencost"
  repository = "https://opencost.github.io/opencost-helm-chart"
  chart      = "opencost"
  version    = var.opencost_version
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  wait       = true

  values = [file("${path.module}/helm/values-opencost.yaml")]

  depends_on = [helm_release.kube_prometheus_stack]
}

# ---------------------------------------------------------------------------
# Pushgateway: training jobs push loss, tokens/sec, and step counters here.
# Batch jobs cannot be scraped directly because they exit before a scrape.
# ---------------------------------------------------------------------------
resource "helm_release" "pushgateway" {
  name       = "prometheus-pushgateway"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-pushgateway"
  version    = var.pushgateway_version
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  wait       = true

  values = [file("${path.module}/helm/values-pushgateway.yaml")]

  depends_on = [helm_release.kube_prometheus_stack]
}

# ---------------------------------------------------------------------------
# Grafana dashboards as code. The kube-prometheus-stack Grafana sidecar loads
# any ConfigMap labelled grafana_dashboard="1".
# ---------------------------------------------------------------------------
resource "kubernetes_config_map_v1" "dashboards" {
  for_each = fileset("${path.module}/dashboards", "*.json")

  metadata {
    name      = "dashboard-${trimsuffix(each.value, ".json")}"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    (each.value) = file("${path.module}/dashboards/${each.value}")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}
