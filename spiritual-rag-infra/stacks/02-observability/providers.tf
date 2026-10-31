# Both providers talk to the cluster created by stacks/01-platform.
# Run `nebius mk8s cluster get-credentials` first so the kubeconfig exists.

provider "kubernetes" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = var.kube_context
}

provider "helm" {
  kubernetes = {
    config_path    = pathexpand(var.kubeconfig_path)
    config_context = var.kube_context
  }
}
