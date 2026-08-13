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

# --- IAP web auth for the load balancer's backend service -----------------
# The brand itself (the OAuth consent screen) is created out-of-band by the
# project owner - one-time, project-wide, effectively irreversible via API,
# and the deployer SA doesn't have permission for it anyway. See
# var.iap_brand_name.
#
# Commented out until var.iap_brand_name is set (currently empty) - leave
# commented until the owner provides it, otherwise apply fails trying to
# create a client with no brand to attach to. The google_compute_backend_
# service.app_backend resource's iap {} block in lb.tf is commented out
# to match - uncomment both together, not just one.

# resource "google_iap_client" "app_client" {
#   display_name = "app-iap-client"
#   brand        = var.iap_brand_name
#
#   depends_on = [google_project_service.apis]
# }
#
# # Least-privilege: grants access to just this one backend service, not the
# # whole project. Add more entries to var.iap_allowed_members for teammates.
# resource "google_iap_web_backend_service_iam_member" "app_access" {
#   for_each = toset(var.iap_allowed_members)
#
#   project             = var.gcp_project
#   web_backend_service = google_compute_backend_service.app_backend.name
#   role                = "roles/iap.httpsResourceAccessor"
#   member              = each.value
# }
