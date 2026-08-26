terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.8.0"
    }
  }

  # State now lives in GCS instead of the local terraform.tfstate file.
  # NOTE: backend blocks can't use variables
  backend "gcs" {
    bucket                      = "c0001-uat-terraform-state"
    prefix                      = "terraform/state"
    impersonate_service_account = "c0001-uat-terraform-deployer@c0001-uat.iam.gserviceaccount.com"
  }
}

provider "google" {
  project = var.gcp_project
  region  = var.region
  zone    = var.zone

  impersonate_service_account = var.terraform_deployer_sa
}
