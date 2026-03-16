terraform {
  required_version = ">= 1.6.0"

  required_providers {
    airbyte = {
      source  = "airbytehq/airbyte"
      version = "~> 1.0"
    }
  }
}
