# Component: HCP Terraform execution and state

**Where:** `versions.tf` (`cloud {}` block) and the HCP Terraform workspace settings
**Docs:** HCP Terraform, Terraform CLI integration

## What it is

HCP Terraform (formerly Terraform Cloud) stores your state, locks it during changes, and records a history of every run. The `cloud {}` block in `versions.tf` tells the Terraform CLI to use it.

## Execution modes

The workspace setting decides where `terraform plan` and `apply` run.

| Mode | Where it runs | Where state lives | Use it here? |
|---|---|---|---|
| **Remote** | HCP Terraform runners | HCP Terraform | No. Runners cannot read the Nebius key file from your machine. |
| **Local** | Your computer | HCP Terraform | **Yes.** This is the default for this repo. |

With **Local** mode, the Nebius key file and environment variables stay on your computer. HCP Terraform still stores state, locks, and history.

In Local mode, variables you set in the HCP workspace are not read by the CLI. Put the values in `terraform.tfvars` or in `TF_VAR_*` environment variables on your machine.

### Remote mode alternative

If you prefer Remote runs, the provider must authenticate without a key file. Options:

- A user access token in `NEBIUS_IAM_TOKEN`, stored as a sensitive workspace variable. It is a user credential with broad rights and expires. Use it only for experiments.
- Nebius-supported workload identity federation, if your account offers it for HCP Terraform. This is not confirmed in this repo. Check the Nebius federation docs.

## Setup

```bash
terraform login          # stores an API token in ~/.terraform.d/credentials.tfrc.json
```

In the HCP Terraform UI:

1. Create the project `spiritual-rag` and the workspaces `spiritual-rag-platform-budget` and `spiritual-rag-observability`.
2. For each workspace, open **Settings > General > Execution Mode** and choose **Local**.
3. Replace `YOUR_HCP_ORG` in both `versions.tf` files with your organization name.

Then `terraform init` in each stack. The first init may ask you to confirm the workspace.

## State and secrets

Terraform state can contain secrets, including the kubeconfig data returned by providers and any sensitive values. Limit who can read the workspace in HCP Terraform, and mark outputs as `sensitive` where possible.

## Cost

HCP Terraform bills per managed resource. The Free tier covers 500 managed resources. The official HashiCorp documentation describes per-resource pricing above that. Third-party sources disagree on tiers and on whether cost estimation is available on each plan. Check the **Usage** page in your organization, and the plan details in the HCP Terraform console, before relying on either.

## References

- HCP Terraform, Terraform CLI integration: https://developer.hashicorp.com/terraform/cli/cloud
- HCP Terraform, cost estimate and managed resource billing: https://developer.hashicorp.com/terraform/cloud-docs/overview/estimate-hcp-terraform-cost
- Nebius Terraform authentication: https://docs.nebius.com/terraform-provider/authentication
