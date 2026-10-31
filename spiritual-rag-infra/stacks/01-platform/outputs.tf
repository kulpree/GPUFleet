output "cluster_id" {
  description = "Managed Kubernetes cluster ID."
  value       = nebius_mk8s_v1_cluster.primary.id
}

output "cluster_name" {
  description = "Managed Kubernetes cluster name."
  value       = nebius_mk8s_v1_cluster.primary.name
}

output "kubeconfig_command" {
  description = "Run this command to add the cluster to ~/.kube/config (external endpoint)."
  value       = "nebius mk8s cluster get-credentials --id ${nebius_mk8s_v1_cluster.primary.id} --external"
}

output "gpu_node_group_name" {
  description = "GPU node group name. Scale it by changing gpu_min_size and gpu_max_size."
  value       = nebius_mk8s_v1_node_group.gpu.name
}

output "bucket_name" {
  description = "Object Storage bucket for the corpus."
  value       = nebius_storage_v1_bucket.corpus.name
}

output "registry_name" {
  description = "Container registry name."
  value       = nebius_registry_v1_registry.apps.name
}

output "workloads_service_account_id" {
  description = "Service account ID for workloads. Grant it bucket and registry access (see docs)."
  value       = nebius_iam_v1_service_account.workloads.id
}
