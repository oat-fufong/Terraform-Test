variable "gcp_project" {
  description = "GCP Project ID"
  type        = string
  default     = "oat-testing-project"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-southeast1"
}

variable "app_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "oat-test"
}