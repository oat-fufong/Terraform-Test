variable "gcp_project" {
  description = "GCP Project ID"
  type        = string
  # No default - required
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-southeast1"
}

variable "zone" {
  description = "GCP Zone (for the Compute Engine VM)"
  type        = string
  default     = "asia-southeast1-a"
}

variable "app_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "oat-test"
}

variable "machine_type" {
  description = "Machine type for the test VM"
  type        = string
  default     = "e2-medium"
}

variable "terraform_deployer_sa" {
  description = "Service account Terraform impersonates to make API calls"
  type        = string
  # No default - required
}

variable "vm_runtime_sa" {
  description = "Service account attached to the VM at runtime (least-privilege, separate from the deployer identity)"
  type        = string
  # No default - required,
}

variable "domain_name" {
  description = "Domain pointed at the load balancer's IP for the managed SSL cert. If left as \"changeme.example.com\", falls back to a sslip.io-derived domain (see local.lb_domain in loadbalancer.tf) - set to a real, DNS-verified domain in terraform.tfvars once available."
  type        = string
  default     = "changeme.example.com"
}

variable "backend_port" {
  description = "Port the app container listens on, that the load balancer forwards to"
  type        = number
  default     = 4321
}

variable "app_allowed_members" {
  description = "Identities granted roles/iap.httpsResourceAccessor on the frontend backend service. Format: \"user:email\" or \"group:email\". No default - who gets access is deliberately explicit per deployment, set in terraform.tfvars."
  type        = list(string)
}

variable "grafana_allowed_members" {
  description = "Identities granted roles/iap.httpsResourceAccessor on the Grafana backend service - independent from app_allowed_members, can be a narrower subset. Format: \"user:email\" or \"group:email\". No default - set in terraform.tfvars. Note: only accounts within your Google Workspace org can authenticate at all right now (the Google-managed OAuth client IAP defaults to is internal-only) - external accounts like personal Gmail need a custom OAuth client first, see conversation/devlog."
  type        = list(string)
}

variable "iap_forwarding_cidr" {
  description = "Google's fixed, globally-shared source range for Identity-Aware Proxy TCP forwarding. Same for every GCP project; do not change unless Google publishes a new range. https://cloud.google.com/iap/docs/using-tcp-forwarding#create-firewall-rule"
  type        = string
  default     = "35.235.240.0/20"
}
