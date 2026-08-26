resource "google_project_service" "artifact_registry_api" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
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

# Pulls: the VM's identity (vm_runtime_sa, attached in compute.tf - a
# dedicated least-privilege SA, separate from terraform_deployer_sa above).
# Scoped to just this repo, not project-wide.
resource "google_artifact_registry_repository_iam_member" "vm_pull" {
  project    = var.gcp_project
  location   = google_artifact_registry_repository.app_repo.location
  repository = google_artifact_registry_repository.app_repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.vm_runtime_sa}"
}
