output "vm_name" {
  description = "Name of the test VM"
  value       = google_compute_instance.vm_instance.name
}

output "vm_internal_ip" {
  description = "Internal IP of the test VM (no external IP is assigned)"
  value       = google_compute_instance.vm_instance.network_interface[0].network_ip
}

output "ssh_command" {
  description = "gcloud command to SSH into the VM via the IAP tunnel"
  value       = "gcloud compute ssh ${google_compute_instance.vm_instance.name} --zone=${var.zone} --project=${var.gcp_project} --tunnel-through-iap"
}

output "api_statuses" {
  description = "Which APIs were enabled"
  value       = { for k, v in google_project_service.apis : k => "ENABLED" }
}
