# Component: Service accounts and authentication

**Terraform resources:** `nebius_iam_v1_service_account.workloads`, provider `service_account` block
**Nebius service:** IAM

## What it is

Two kinds of identity appear in this stack:

1. **Terraform's identity.** A service account with an authorized key. Terraform uses it to create and change resources. This is the one you set up before the first run.
2. **Workload identity.** A second service account, `spiritual-rag-workloads`, for the running pods (ingest, training, RAG API) to read and write the bucket and pull images.

Keep them separate. Terraform needs edit rights on the project. Workloads need only the access they use.

## Setting up Terraform's identity

Follow the Nebius quickstart. In outline:

```bash
# 1. Create the service account and key
export SA_ID=$(nebius iam service-account create --name terraform-sa --format json | jq -r '.metadata.id')
nebius iam auth-public-key create --account-service-account-id $SA_ID --data "$(cat public.pem)" --format json

# 2. Grant it edit access (group membership to the editors group of your tenant)
export EDITORS_GROUP_ID=$(nebius iam group get-by-name --name editors --parent-id <tenant_id> --format json | jq -r '.metadata.id')
nebius iam group-membership create --parent-id $EDITORS_GROUP_ID --member-id $SA_ID

# 3. Export the values that providers.tf reads
export NEBIUS_SA_ID=$SA_ID
export NEBIUS_PUBLIC_KEY_ID=<public key id from step 1>
export NEBIUS_PRIVATE_KEY_FILE=$HOME/.nebius/authkey/private.pem
```

Treat `private.pem` like a password. Keep its permissions at `600` and do not commit it.

## How providers.tf uses it

```hcl
provider "nebius" {
  service_account = {
    account_id_env       = "NEBIUS_SA_ID"
    public_key_id_env    = "NEBIUS_PUBLIC_KEY_ID"
    private_key_file_env = "NEBIUS_PRIVATE_KEY_FILE"
  }
}
```

The `*_env` form reads the values from the environment, so no secret appears in code. The Nebius authentication guide also documents a direct form and a user-token form (`NEBIUS_IAM_TOKEN`). Prefer the service account. A user token is for local experiments only.

## Workload identity

`nebius_iam_v1_service_account.workloads` creates the identity. Give it access in two steps:

1. **Bucket access:** an access permit that grants the account read/write on the bucket. The provider lists `nebius_iam_v1_access_permit`. Confirm its arguments in the reference before adding it, since they are not set in this repo.
2. **Access key for S3 calls:** create a key for the account with the Nebius CLI or console, and store it in a Kubernetes Secret named the same as the one that the pods read.

## Rules

- No key files or access keys in Git, container images, or Terraform variables that you commit.
- Rotate keys if a laptop or CI runner is lost.
- In HCP Terraform, do not store the Terraform key in a remote workspace variable. Use Local execution mode (see [execution-and-state.md](execution-and-state.md)).

## References

- Nebius Terraform authentication: https://docs.nebius.com/terraform-provider/authentication
- Nebius Terraform quickstart: https://docs.nebius.com/terraform-provider/quickstart
- Authorized keys for service accounts: https://docs.nebius.com/iam/service-accounts/authorized-keys
- Terraform provider configuration: https://docs.nebius.com/terraform-provider/reference/provider
