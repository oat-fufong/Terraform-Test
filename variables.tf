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

variable "iap_forwarding_cidr" {
  description = "Google's fixed, globally-shared source range for Identity-Aware Proxy TCP forwarding. Same for every GCP project; do not change unless Google publishes a new range. https://cloud.google.com/iap/docs/using-tcp-forwarding#create-firewall-rule"
  type        = string
  default     = "35.235.240.0/20"
}
