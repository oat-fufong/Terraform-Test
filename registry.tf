resource "google_project_service" "artifact_registry_api" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# The VM runs under GCE's default compute SA (see compute.tf). Computed from
# the project number rather than hardcoded - the email format is fixed and
# predictable ("${project_number}-compute@developer..."). Uses google_project
# (needs only resourcemanager.projects.get) instead of
# google_compute_default_service_account, which needs iam.serviceAccounts.get
# - a permission terraform_deployer_sa doesn't have (confirmed via a prior
# apply error).
data "google_project" "current" {
  project_id = var.gcp_project
}

locals {
  default_compute_sa = "${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

resource "google_artifact_registry_repository" "app_repo" {
  depends_on = [google_project_service.artifact_registry_api]

  repository_id = "app-images"
  location      = var.region
  format        = "DOCKER"
}

# Pushes: the deployer identity already impersonated for `terraform apply`
# (see main.tf) - deploy scripts reuse the same impersonation to push images,
# so no separate grant is needed for whoever runs the deploy script.
resource "google_artifact_registry_repository_iam_member" "deployer_push" {
  project    = var.gcp_project
  location   = google_artifact_registry_repository.app_repo.location
  repository = google_artifact_registry_repository.app_repo.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.terraform_deployer_sa}"
}

# Pulls: the VM's identity (GCE default compute SA - see compute.tf for why
# it's not a dedicated least-privilege SA). Still scoped to just this repo,
# not project-wide, even though the SA itself is broader than ideal.
#
# PENDING (see iam-grants-needed.txt): once vm_runtime_sa can be attached to
# the VM, swap this member to "serviceAccount:${var.vm_runtime_sa}" instead -
# and at that point local.default_compute_sa/data.google_project.current
# above are no longer needed either.
resource "google_artifact_registry_repository_iam_member" "vm_pull" {
  project    = var.gcp_project
  location   = google_artifact_registry_repository.app_repo.location
  repository = google_artifact_registry_repository.app_repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${local.default_compute_sa}"
}
