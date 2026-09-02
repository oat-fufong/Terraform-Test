variable "gcp_project" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "zone" {
  description = "GCP Zone (for the Compute Engine VM)"
  type        = string
}

variable "app_name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "machine_type" {
  description = "Machine type for the test VM"
  type        = string
}

variable "terraform_deployer_sa" {
  description = "Service account Terraform impersonates to make API calls"
  type        = string
}

variable "vm_runtime_sa" {
  description = "Service account attached to the VM at runtime (least-privilege, separate from the deployer identity)"
  type        = string
}

variable "domain_name" {
  description = "Domain pointed at the load balancer's IP for the managed SSL cert. If set to \"changeme.example.com\" in terraform.tfvars, falls back to a sslip.io-derived domain (see local.lb_domain in loadbalancer.tf) - set to a real, DNS-verified domain once available."
  type        = string
}

variable "backend_port" {
  description = "Port the app container listens on, that the load balancer forwards to"
  type        = number
  # No default - required
}

variable "app_allowed_members" {
  description = "Identities granted roles/iap.httpsResourceAccessor on the frontend backend service. Format: \"user:email\" or \"group:email\". No default - who gets access is deliberately explicit per deployment, set in terraform.tfvars."
  type        = list(string)
}

variable "grafana_allowed_members" {
  description = "Identities granted roles/iap.httpsResourceAccessor on the Grafana backend service - independent from app_allowed_members, can be a narrower subset. Format: \"user:email\" or \"group:email\". No default - set in terraform.tfvars. Note: only accounts within your Google Workspace org can authenticate at all right now (the Google-managed OAuth client IAP defaults to is internal-only) - external accounts like personal Gmail need a custom OAuth client first, see conversation/devlog."
  type        = list(string)
}

# Not referenced by any resource - the grant it documents is set up
# manually instead (see the comment in compute.tf near the VM's
# service_account block, and iam-grants-needed.txt). Kept declared so
# terraform.tfvars stays self-documenting about who's expected to have SSH
# access, and in case a future grant to terraform_deployer_sa makes it
# worth Terraform-managing again.
variable "vm_ssh_allowed_members" {
  description = "Identities that should be granted roles/iam.serviceAccountUser on vm_runtime_sa (manually, not via Terraform - see comment above), so they're allowed to OS-Login SSH into the VM. Required because the VM runs as vm_runtime_sa - anyone who can SSH in can act with that SA's privileges via the metadata server, so GCP requires this explicit grant on top of the general compute.osLogin role. Format: \"user:email\" or \"group:email\". No default - set in terraform.tfvars."
  type        = list(string)
}

variable "iap_forwarding_cidr" {
  description = "Google's fixed, globally-shared source range for Identity-Aware Proxy TCP forwarding. Same for every GCP project; do not change unless Google publishes a new range. https://cloud.google.com/iap/docs/using-tcp-forwarding#create-firewall-rule"
  type        = string
}
