variable "gcp_project" {
  description = "GCP Project ID"
  type        = string
  default     = "c0001-uat"
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
  default     = "e2-micro"
}

variable "terraform_deployer_sa" {
  description = "Service account Terraform impersonates to make API calls"
  type        = string
  default     = "c0001-uat-terraform-deployer@c0001-uat.iam.gserviceaccount.com"
}

variable "vm_runtime_sa" {
  description = "Service account attached to the VM at runtime (least-privilege, separate from the deployer identity)"
  type        = string
  default     = "c0001-uat-vm-runtime@c0001-uat.iam.gserviceaccount.com"
}

variable "domain_name" {
  description = "Domain pointed at the load balancer's IP for the managed SSL cert. PLACEHOLDER until a real domain is available - the cert will sit in PROVISIONING until this is a real, DNS-verifiable domain."
  type        = string
  default     = "changeme.example.com"
}

variable "backend_port" {
  description = "Port the app container listens on, that the load balancer forwards to"
  type        = number
  default     = 8080
}

# These two aren't consumed by any resource anymore - Terraform doesn't
# create the brand. Kept as the values to hand the project owner when asking
# them to create it (Console: APIs & Services > OAuth consent screen).
variable "iap_support_email" {
  description = "Support email to request for the IAP/OAuth consent screen, when asking the project owner to create the brand"
  type        = string
  default     = "natakorn.s@fufonglabs.com"
}

variable "iap_application_title" {
  description = "Application name to request for the IAP/OAuth consent screen, when asking the project owner to create the brand"
  type        = string
  default     = "Terraform Test"
}

variable "iap_brand_name" {
  description = "Resource name of the IAP brand once the project owner creates it, format projects/{project_number}/brands/{brand_id}. Find it with: gcloud alpha iap oauth-brands list --project=<project>. Leave blank until then - google_iap_client will fail to create without it."
  type        = string
  default     = ""
}

variable "iap_allowed_members" {
  description = "Identities granted roles/iap.httpsResourceAccessor on the backend service. Format: \"user:email\" or \"group:email\"."
  type        = list(string)
  default     = ["user:natakorn.s@fufonglabs.com"]
}

variable "iap_forwarding_cidr" {
  description = "Google's fixed, globally-shared source range for Identity-Aware Proxy TCP forwarding. Same for every GCP project; do not change unless Google publishes a new range. https://cloud.google.com/iap/docs/using-tcp-forwarding#create-firewall-rule"
  type        = string
  default     = "35.235.240.0/20"
}
