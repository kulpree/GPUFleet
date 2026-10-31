locals {
  common_labels = merge(var.labels, { region = var.region_label })

  gpu_taint = {
    key    = "nvidia.com/gpu"
    value  = "true"
    effect = "NoSchedule"
  }
}

# ---------------------------------------------------------------------------
# Kubernetes control plane (managed by Nebius)
# ---------------------------------------------------------------------------
resource "nebius_mk8s_v1_cluster" "primary" {
  name      = var.cluster_name
  parent_id = var.project_id
  labels    = local.common_labels

  control_plane = {
    endpoints = {
      public_endpoint = {
        # Restricts the public API endpoint to your address(es).
        allowed_cidrs = var.admin_cidrs
      }
    }
    version           = var.k8s_version
    subnet_id         = var.subnet_id
    etcd_cluster_size = var.etcd_cluster_size
  }
}

# ---------------------------------------------------------------------------
# CPU node group: cluster add-ons, ingest jobs, RAG API
# ---------------------------------------------------------------------------
resource "nebius_mk8s_v1_node_group" "cpu" {
  name      = "${var.cluster_name}-cpu"
  parent_id = var.project_id # VERIFY: node groups use the project as parent in this provider version
  labels    = local.common_labels

  autoscaling = {
    min_node_count = var.cpu_worker_min
    max_node_count = var.cpu_worker_max
  }

  template = {
    resources = {
      platform = var.cpu_platform
      preset   = var.cpu_preset
    }
    metadata = {
      labels = { "workload" = "cpu" }
    }
  }
}

# ---------------------------------------------------------------------------
# GPU node group: training and inference. Scales to zero by default.
# ---------------------------------------------------------------------------
resource "nebius_mk8s_v1_node_group" "gpu" {
  name      = "${var.cluster_name}-gpu"
  parent_id = var.project_id # VERIFY: see note on the CPU node group
  labels    = local.common_labels

  autoscaling = {
    min_node_count = var.gpu_min_size
    max_node_count = min(var.gpu_max_size, var.budget_gpu_node_cap)
  }

  template = {
    resources = {
      platform = var.gpu_platform
      preset   = var.gpu_preset
    }
    gpu_settings = {
      drivers_preset = var.gpu_driver_preset
    }
    preemptible = var.gpu_preemptible ? {} : null

    # Taint keeps CPU pods off expensive GPU nodes. GPU pods must tolerate it.
    taints = [local.gpu_taint] # VERIFY: taint attribute shape in the provider reference

    metadata = {
      labels = { "workload" = "gpu" }
    }
  }
}

# ---------------------------------------------------------------------------
# Object Storage: raw PDFs, extracted text, chunks, evaluation output
# ---------------------------------------------------------------------------
resource "nebius_storage_v1_bucket" "corpus" {
  name      = var.bucket_name
  parent_id = var.project_id
}

# ---------------------------------------------------------------------------
# Container registry for application images
# ---------------------------------------------------------------------------
resource "nebius_registry_v1_registry" "apps" {
  name        = var.registry_name
  parent_id   = var.project_id
  description = "Images for the spiritual-rag ingest, training, and RAG API services"
}

# ---------------------------------------------------------------------------
# Service account for workloads (bucket and registry access is granted in
# IAM; see docs/service-accounts.md for the access-permit step)
# ---------------------------------------------------------------------------
resource "nebius_iam_v1_service_account" "workloads" {
  name      = "spiritual-rag-workloads"
  parent_id = var.project_id
}
