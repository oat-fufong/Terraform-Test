terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project != "" ? var.gcp_project : data.google_client_config.current.project
  region  = var.region
}

data "google_client_config" "current" {}

# Enable required GCP APIs
resource "google_project_service" "apis" {
  for_each           = toset(["run.googleapis.com", "artifactregistry.googleapis.com"])
  service            = each.value
  disable_on_destroy = false
}

# Cloud Run service (runs a container)
resource "google_cloud_run_v2_service" "app" {
  name     = var.app_name
  location = var.region
  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
      ports {
        container_port = 8080
      }
    }
  }

  depends_on = [google_project_service.apis]
}