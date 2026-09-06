terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0, < 6.0"
    }
  }

  # Terraform state is stored remotely in GCS so that both
  # bin/up.sh and bin/down.sh share the same state across runs.
  backend "gcs" {
    # bucket is created by bin/gcp-init.sh (can't self-reference in backend)
  }
}
