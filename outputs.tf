output "service_url" {
  description = "Public URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.app.uri
}

output "api_statuses" {
  description = "Which APIs were enabled"
  value       = { for s in google_project_service.apis : s.service => s.state }
}