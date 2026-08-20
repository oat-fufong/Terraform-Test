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

variable "terraform_deployer_sa" {
  description = "Service account Terraform impersonates to make API calls"
  type        = string
  # No default - required
}
