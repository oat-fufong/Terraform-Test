output "vm_name" {
  description = "Name of the test VM"
  value       = google_compute_instance.vm_instance.name
}

output "vm_internal_ip" {
  description = "Internal IP of the test VM"
  value       = google_compute_instance.vm_instance.network_interface[0].network_ip
}

output "lb_ip_address" {
  description = "Load balancer's reserved external IP - point var.domain_name's DNS A record here once a real domain is available"
  value       = google_compute_global_address.app_ip.address
}

output "lb_http_test_url" {
  description = "Test the LB chain, no domain/cert needed - same IAP protection as the HTTPS URL, just unencrypted"
  value       = "http://${google_compute_global_address.app_ip.address}/"
}

output "lb_https_test_url" {
  description = "Main app URL, IAP-protected. sslip.io fallback until var.domain_name is a real domain. Cert takes a few minutes to move from PROVISIONING to ACTIVE after apply."
  value       = "https://${local.lb_domain}/"
}

output "grafana_url" {
  description = "Grafana, IAP-protected. Same domain and cert as the main app, routed by path - requires Grafana's own GF_SERVER_ROOT_URL/GF_SERVER_SERVE_FROM_SUB_PATH config to actually work correctly."
  value       = "https://${local.lb_domain}/grafana/"
}

output "cert_status_command" {
  description = "Check the managed cert's status (name is auto-generated, changes whenever the domain changes)"
  value       = "gcloud compute ssl-certificates describe ${local.cert_name} --global --project=${var.gcp_project} --format='get(managed.status,managed.domainStatus)'"
}

output "ssh_command" {
  description = "gcloud command to SSH into the VM via the IAP tunnel"
  value       = "gcloud compute ssh ${google_compute_instance.vm_instance.name} --zone=${var.zone} --project=${var.gcp_project} --tunnel-through-iap"
}

output "api_statuses" {
  description = "Which APIs were enabled"
  value       = { for k, v in google_project_service.apis : k => "ENABLED" }
}
