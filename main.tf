terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "6.8.0"
    }
  }

  # State now lives in GCS instead of the local terraform.tfstate file.
  # NOTE: backend blocks can't use variables
  backend "gcs" {
    bucket = "c0001-uat-terraform-state"
    prefix = "terraform/state"
    impersonate_service_account = "c0001-uat-terraform-deployer@c0001-uat.iam.gserviceaccount.com"
  }
}

provider "google" {
  project = "${var.gcp_project}"
  region  = "${var.region}"
  zone    = "${var.zone}"

  impersonate_service_account = var.terraform_deployer_sa
}

resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}

# Terraform state bucket
resource "google_storage_bucket" "terraform_state" {
  name                        = "${var.gcp_project}-terraform-state"
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age                = 30
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = "${var.machine_type}"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }

  metadata = {
    enable-oslogin = "TRUE"
    startup-script = file("install_docker.sh")
  }
}

# Enable required GCP APIs
resource "google_project_service" "apis" {
  for_each           = toset(["compute.googleapis.com", "oslogin.googleapis.com", "storage.googleapis.com"])
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-ssh-from-iap"
  network = google_compute_network.vpc_network.name

  # the IP range Google uses for IAP.
  source_ranges = ["35.235.240.0/20"] 

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

}
