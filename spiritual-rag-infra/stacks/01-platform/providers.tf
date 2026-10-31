# Authentication uses a Nebius service account and an authorized key.
# Nothing secret lives in this file: the provider reads the IDs and the key
# file path from environment variables. See docs/service-accounts.md.
#
#   export SA_ID=$(nebius iam service-account get-by-name --name terraform-sa --format json | jq -r '.metadata.id')
#   export NEBIUS_SA_ID="$SA_ID"
#   export NEBIUS_PUBLIC_KEY_ID="publickey-..."
#   export NEBIUS_PRIVATE_KEY_FILE="$HOME/.nebius/authkey/private.pem"

provider "nebius" {
  service_account = {
    account_id_env       = "NEBIUS_SA_ID"
    public_key_id_env    = "NEBIUS_PUBLIC_KEY_ID"
    private_key_file_env = "NEBIUS_PRIVATE_KEY_FILE"
  }

  # Default project for resources that do not set parent_id explicitly.
  parent_id = var.project_id
}
