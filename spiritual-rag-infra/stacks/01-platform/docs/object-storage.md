# Component: Object Storage bucket

**Terraform resource:** `nebius_storage_v1_bucket.corpus`
**Nebius service:** Object Storage (S3-compatible)

## What it is

A bucket that stores objects (files) behind an S3-compatible API. Standard S3 tools and SDKs work with it when pointed at the Nebius endpoint.

## Why it is here

The RAG system needs a durable place for:

| Prefix | Contents | Written by |
|---|---|---|
| `raw/<lang>/<tradition>/` | Original PDFs | You, by upload |
| `chunks/` | JSONL of normalized, citable chunks | `apps/ingest` |
| `models/` | LoRA adapters | `apps/train` |
| `eval/` | Evaluation results per language | Evaluation runs |

Cluster disks are ephemeral in this design. Anything that must survive a node or cluster rebuild goes in the bucket.

## Key settings

| Argument | Value | Notes |
|---|---|---|
| `name` | `var.bucket_name` | Must be unique. Use a suffix such as your initials and a number. |
| `parent_id` | `var.project_id` | Bucket belongs to this project. |

## Access from workloads

The ingest job uses environment variables for S3 access:

```bash
export NEBIUS_S3_ENDPOINT=<regional S3 endpoint>   # VERIFY in the Nebius storage docs
export NEBIUS_S3_ACCESS_KEY=<key>
export NEBIUS_S3_SECRET_KEY=<secret>
export NEBIUS_BUCKET=<bucket name>
```

Create the access key for the workload service account, and store it in a Kubernetes Secret, not in the image or in Git. See [service-accounts.md](service-accounts.md).

## Cost

Storage and egress are billed. PDFs are small, but `chunks/` and `eval/` grow with every ingest run. Delete old chunk files you have superseded. Keep egress low by running ingest and training in the same region as the bucket.

## Verify before use

- The S3 endpoint for your region.
- Whether the bucket needs a versioning or lifecycle setting for cost control. The example bucket resource sets neither.

## References

- Nebius Object Storage docs: https://docs.nebius.com/storage (VERIFY current path)
- Terraform resource: https://docs.nebius.com/terraform-provider/reference/resources/storage_v1_bucket
- Terraform state in a bucket (Nebius guide): https://docs.nebius.com/terraform-provider/
