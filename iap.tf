# Least-privilege: grants access to just this one backend service, not the
# whole project. Add more entries to var.app_allowed_members for teammates.
resource "google_iap_web_backend_service_iam_member" "app_access" {
  for_each = toset(var.app_allowed_members)

  project             = var.gcp_project
  web_backend_service = google_compute_backend_service.app_backend.name
  role                = "roles/iap.httpsResourceAccessor"
  member              = each.value
}

# Separate IAP grant, scoped to just the Grafana backend
# Independent list (var.grafana_allowed_members)
resource "google_iap_web_backend_service_iam_member" "grafana_access" {
  for_each = toset(var.grafana_allowed_members)

  project             = var.gcp_project
  web_backend_service = google_compute_backend_service.grafana_backend.name
  role                = "roles/iap.httpsResourceAccessor"
  member              = each.value
}
