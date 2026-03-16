terraform {
  required_version = ">= 1.6.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.37"
    }

    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.26"
    }

  }
}
