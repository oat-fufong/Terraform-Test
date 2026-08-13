# Resources that get created once 

# Terraform's own remote state. Created with local state first, then
# main.tf's backend "gcs" block was pointed at it (see main.tf).
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

# Enable required GCP APIs
resource "google_project_service" "apis" {
  for_each           = toset(["compute.googleapis.com", "oslogin.googleapis.com", "storage.googleapis.com", "iap.googleapis.com"])
  service            = each.value
  disable_on_destroy = false
}
