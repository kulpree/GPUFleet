terraform {
  required_version = ">= 1.6.0"

  # State is stored in HCP Terraform. Runs execute locally (see README,
  # "Execution mode"), so the Nebius service account key file stays on your machine.
  cloud {
    organization = "YOUR_HCP_ORG" # replace with your HCP Terraform organization

    workspaces {
      name = "spiritual-rag-platform-budget"
    }
  }

  required_providers {
    nebius = {
      source  = "nebius/nebius"
      version = "~> 0.6.16"
    }
  }
}
