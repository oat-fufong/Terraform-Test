resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = "${var.machine_type}"

  # Resizing machine_type requires the instance to be stopped first. 
  # apply stops -> resizes -> restarts automatically.
  allow_stopping_for_update = true

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

  tags = ["lb-backend"]

  # Attaching ANY service account here - even GCE's own default one, not
  # just a custom SA - requires terraform_deployer_sa to hold
  # roles/iam.serviceAccountUser on that SA. It currently has this on NONE
  # of them (confirmed by hitting this exact error for both vm_runtime_sa
  # and the default compute SA). Real fix needs a project Owner to grant
  # terraform_deployer_sa roles/iam.serviceAccountUser - ideally project-wide
  # on serviceAccountUser, since we've now hit this same wall for two
  # different SAs and would hit it again for any future one.
  #
  # PENDING (see iam-grants-needed.txt) - once granted, uncomment this and
  # remove registry.tf's default_compute_sa fallback + its vm_pull member:
  # service_account {
  #   email  = var.vm_runtime_sa
  #   scopes = ["cloud-platform"]
  # }
}

# PENDING (see iam-grants-needed.txt) - needs iam.googleapis.com enabled to
# manage IAM policy on a specific service account.
# resource "google_project_service" "iam_api" {
#   service            = "iam.googleapis.com"
#   disable_on_destroy = false
# }

# PENDING (see iam-grants-needed.txt) - grants *you* roles/iam.serviceAccountUser
# on vm_runtime_sa, separately from the grant terraform_deployer_sa needs, so
# OS Login lets you SSH into a VM running as it.
# resource "google_service_account_iam_member" "vm_ssh_access" {
#   depends_on = [google_project_service.iam_api]
#   for_each   = toset(var.vm_ssh_allowed_members)
#
#   service_account_id = "projects/${var.gcp_project}/serviceAccounts/${var.vm_runtime_sa}"
#   role                = "roles/iam.serviceAccountUser"
#   member              = each.value
# }

resource "google_compute_instance_group" "app_ig" {
  name = "app-instance-group"
  zone = var.zone

  instances = [google_compute_instance.vm_instance.self_link]

  named_port {
    name = "http"
    port = var.backend_port
  }
  named_port {
    name = "grafana"
    port = 3001
  }
}
