# Separate, one-time-ish root module: creates the state bucket the main
# config's backend "gcs" block points at, plus the project APIs.
# Run this once per project, before ever touching the main config.
#
# Usage:
#   cd bootstrap
#   terraform init
#   terraform apply

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.8.0"
    }
  }
}

provider "google" {
  project                     = var.gcp_project
  region                      = var.region
  impersonate_service_account = var.terraform_deployer_sa
}

resource "google_storage_bucket" "terraform_state" {
  name                        = "${var.gcp_project}-terraform-state"
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age                = 30
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_project_service" "apis" {
  for_each           = toset(["compute.googleapis.com", "oslogin.googleapis.com", "storage.googleapis.com", "iap.googleapis.com"])
  service            = each.value
  disable_on_destroy = false
}
