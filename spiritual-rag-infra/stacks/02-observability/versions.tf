terraform {
  required_version = ">= 1.6.0"

  cloud {
    organization = "YOUR_HCP_ORG" # replace with your HCP Terraform organization

    workspaces {
      name = "spiritual-rag-observability"
    }
  }

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}
