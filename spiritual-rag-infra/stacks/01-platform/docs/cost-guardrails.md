# Component: Cost guardrails

**Where:** `variables.tf` (validations), `main.tf` (GPU cap), and the observability stack (alerts)
**Budget:** USD 100 per project, Nebius billing

## Why this exists

A GPU left running can spend the whole budget in a day. The guardrails make the expensive mistake hard to make, and make it obvious when it happens.

## Layers

| Layer | Mechanism | Stops |
|---|---|---|
| 1. Default size | `gpu_min_size = 0` | GPU billing when nothing runs |
| 2. Hard cap | `budget_gpu_node_cap = 1` and `min(gpu_max_size, cap)` | Scaling beyond one GPU, even by mistake |
| 3. Validations | `etcd_cluster_size` in {1,3}; no `0.0.0.0/0` in `admin_cidrs` | Unsafe or unexpected settings |
| 4. Single region | Only one cluster in this stack | Doubling the baseline cost |
| 5. Alerts | Idle GPU, run-rate over budget, nodes with no pods | Waste that is already happening |
| 6. Manual process | Check the Cost dashboard before and after each run | Human error |

## What the guardrails do not do

- **They do not cap total spend.** Terraform cannot read your Nebius bill. The run-rate alert projects the cost of the current hourly rate. Cumulative spend must be checked in Nebius billing.
- **They do not stop the autoscaler.** If a pod requests a GPU and `max_size` allows it, a node starts. Set `budget_gpu_node_cap` to match what you can afford.
- **They do not account for storage or egress** unless you check the bills.

## Budget arithmetic

At the on-demand price cited in the README (USD 4.50 per GPU-hour for H100, at the October 2026 rate reported by third-party trackers), USD 100 buys about 22 GPU-hours. Preemptible pricing is lower, around USD 2.15 per GPU-hour in the same reports, so about 46 hours. Verify current prices before you plan a run.

| Use | GPU-hours | Approx. cost (on-demand) |
|---|---|---|
| One LoRA run of about 3 hours | 3 | USD 13.50 |
| Inference demo of 4 hours | 4 | USD 18 |
| Idle GPU for a day by mistake | 24 | USD 108 |

The last row is why the idle-GPU alert exists.

## Procedure before each GPU run

1. Set `gpu_max_size = 1` and apply. Confirm the node count with `kubectl get nodes -L workload`.
2. Check the Cost dashboard's current hourly rate.
3. Run the job with a time limit in mind.
4. Set `gpu_max_size = 0` and apply after the job ends. Confirm the GPU node is gone.

## Verify

- Whether Nebius offers budget alerts in billing. If it does, set them at USD 50 and USD 80.
- Whether HCP Terraform cost estimation is available on your plan, since the sources disagree (see [execution-and-state.md](execution-and-state.md)).

## References

- Nebius pricing: https://nebius.com/prices
- Terraform validation blocks: https://developer.hashicorp.com/terraform/language/values/variables#custom-validation-rules
