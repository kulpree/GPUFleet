# Component: GPU node group

**Terraform resource:** `nebius_mk8s_v1_node_group.gpu`

## What it is

A pool of GPU worker nodes. Nebius installs NVIDIA drivers from the `gpu_settings.drivers_preset`, and the node group exposes the GPUs to Kubernetes.

## Why it is here

Two workloads need a GPU: LoRA fine-tuning (`apps/train`) and vLLM inference (`apps/k8s/inference-vllm.yaml`). Both are billed by the hour while the node runs. With a USD 100 budget, the pool must be off unless a job is using it.

## Key settings

| Argument | Value | Reason |
|---|---|---|
| `autoscaling.min_node_count` | `var.gpu_min_size`, default `0` | No GPU is billed when idle. |
| `autoscaling.max_node_count` | `min(var.gpu_max_size, var.budget_gpu_node_cap)` | The budget cap is applied even if someone raises `gpu_max_size`. |
| `template.resources.platform` | `gpu-h100-sxm` (VERIFY) | Check the GPU catalog and availability in your region. |
| `template.resources.preset` | `1gpu-16vcpu-200gb` (VERIFY) | One GPU keeps cost predictable. |
| `template.gpu_settings.drivers_preset` | `cuda12` | The CLI reference lists `cuda12` for Kubernetes 1.31. Confirm for your version. |
| `template.preemptible` | `{}` when `gpu_preemptible = true` | Preemptible nodes cost less. They can be reclaimed, so training must checkpoint. |
| `template.taints` | `nvidia.com/gpu=true:NoSchedule` (VERIFY shape) | Keeps non-GPU pods off the expensive nodes. |
| `template.metadata.labels` | `workload: gpu` | Lets pods select the pool. |

## How to use it

1. Set `gpu_min_size = 0` and `gpu_max_size = 1` (the defaults). Apply. The pool has no nodes and no GPU charge.
2. For a run, set `gpu_max_size = 1` and apply again. Or let the autoscaler start a node when a pod requests `nvidia.com/gpu`, if the autoscaler is enabled for your cluster.
3. When the job ends, set `gpu_max_size` back to `0` or let the autoscaler scale down. Check the Cost dashboard afterward.

**Caution:** the autoscaler can start a node without anyone noticing. Keep the Cost dashboard and the idle-GPU alert on.

## Pods that use the GPU

A pod needs three things to land here:

```yaml
nodeSelector:
  workload: gpu
tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
resources:
  limits:
    nvidia.com/gpu: 1
```

See `apps/k8s/train-job.yaml` and `apps/k8s/inference-vllm.yaml`.

## Preemption

Preemptible nodes can be stopped at short notice. For training:

- Save a checkpoint every few hundred steps (the `save_steps` setting in `apps/train/train.py`).
- Keep the job's `backoffLimit` above zero so Kubernetes retries after a preemption.
- Write checkpoints to durable storage if you need to resume after the pod is deleted. The example job uses `emptyDir`, which does not survive pod deletion.

## References

- Terraform resource: https://docs.nebius.com/terraform-provider/reference/resources/mk8s_v1_node_group
- Nebius CLI node group options (GPU settings, preemptible, taints): https://docs.nebius.com/cli/reference/mk8s/v1alpha1/node-group/create
- NVIDIA device plugin and taints, Kubernetes: https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
