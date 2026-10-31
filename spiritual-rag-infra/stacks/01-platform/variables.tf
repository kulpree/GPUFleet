variable "project_id" {
  description = "Nebius project ID (parent_id for all resources in this stack)."
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must be set."
  }
}

variable "cluster_name" {
  description = "Name of the Managed Kubernetes cluster."
  type        = string
  default     = "spiritual-rag-primary"
}

variable "region_label" {
  description = "Human-readable region label, used for tagging only. The region is determined by the project and subnet."
  type        = string
  default     = "eu-north1"
}

variable "subnet_id" {
  description = "Existing VPC subnet ID for the control plane and nodes. Find it with: nebius vpc subnet list --format json"
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes control plane version. Check supported versions with: nebius mk8s cluster list-control-plane-versions"
  type        = string
  default     = "1.32"
}

variable "etcd_cluster_size" {
  description = "Number of etcd members. 1 is cheapest for development; use 3 for anything you cannot afford to rebuild."
  type        = number
  default     = 1

  validation {
    condition     = contains([1, 3], var.etcd_cluster_size)
    error_message = "etcd_cluster_size must be 1 or 3."
  }
}

variable "admin_cidrs" {
  description = "CIDR blocks allowed to reach the public Kubernetes API endpoint. Use your own public IP as x.x.x.x/32. Never 0.0.0.0/0."
  type        = list(string)

  validation {
    condition     = !contains(var.admin_cidrs, "0.0.0.0/0")
    error_message = "admin_cidrs must not contain 0.0.0.0/0."
  }
}

variable "system_node_count" {
  description = "Fixed number of CPU nodes for cluster add-ons (always on)."
  type        = number
  default     = 1
}

variable "cpu_platform" {
  description = "CPU platform for the system and CPU worker node groups. Verify the value against the Nebius catalog."
  type        = string
  default     = "cpu-d3" # VERIFY in the Nebius console or CLI before applying
}

variable "cpu_preset" {
  description = "CPU preset (vCPU and memory) for CPU nodes. Verify the value against the Nebius catalog."
  type        = string
  default     = "4vcpu-16gb" # VERIFY in the Nebius console or CLI before applying
}

variable "cpu_worker_min" {
  description = "Minimum CPU worker nodes (autoscaling lower bound)."
  type        = number
  default     = 0
}

variable "cpu_worker_max" {
  description = "Maximum CPU worker nodes (autoscaling upper bound)."
  type        = number
  default     = 2
}

variable "gpu_platform" {
  description = "GPU platform for the GPU node group. Verify the value against the Nebius catalog."
  type        = string
  default     = "gpu-h100-sxm" # VERIFY in the Nebius console or CLI before applying
}

variable "gpu_preset" {
  description = "GPU preset (GPU count, vCPU, memory) for GPU nodes. Verify the value against the Nebius catalog."
  type        = string
  default     = "1gpu-16vcpu-200gb" # VERIFY in the Nebius console or CLI before applying
}

variable "gpu_driver_preset" {
  description = "Driver preset that the GPU image uses. The CLI reference lists \"cuda12\" for Kubernetes 1.31."
  type        = string
  default     = "cuda12"
}

variable "gpu_min_size" {
  description = "Minimum GPU nodes. Keep at 0 so no GPU is billed unless a job is running."
  type        = number
  default     = 0
}

variable "gpu_max_size" {
  description = "Maximum GPU nodes. The budget guard below limits this to budget_gpu_node_cap."
  type        = number
  default     = 1
}

variable "budget_gpu_node_cap" {
  description = "Hard ceiling on GPU nodes for this workspace. Raise it deliberately, not by accident."
  type        = number
  default     = 1
}

variable "gpu_preemptible" {
  description = "Use preemptible GPU nodes. Cheaper, but nodes can be reclaimed. Pair with checkpointing."
  type        = bool
  default     = true
}

variable "bucket_name" {
  description = "Object Storage bucket for PDFs, chunks, and evaluation output. Must be globally unique within your Nebius account scope."
  type        = string
}

variable "registry_name" {
  description = "Container registry name for the application images."
  type        = string
  default     = "spiritual-rag"
}

variable "labels" {
  description = "Extra labels applied to resources that support them."
  type        = map(string)
  default = {
    app     = "spiritual-rag"
    managed = "terraform"
  }
}
