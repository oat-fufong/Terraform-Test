resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = var.machine_type

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

  service_account {
    email  = var.vm_runtime_sa
    scopes = ["cloud-platform"]
  }
}

# NOT Terraform-managed, deliberately: granting var.vm_ssh_allowed_members
# roles/iam.serviceAccountUser on vm_runtime_sa (so OS Login lets them SSH
# into a VM running as it) requires terraform_deployer_sa to hold
# iam.serviceAccounts.getIamPolicy/setIamPolicy on vm_runtime_sa (i.e.
# roles/iam.serviceAccountAdmin) - a much broader grant than the actAs-only
# roles/iam.serviceAccountUser it already has from attaching the SA to the
# VM above. Not worth requesting just to let Terraform re-manage a grant
# that already exists. Set up manually instead (see iam-grants-needed.txt):
#
# gcloud iam service-accounts add-iam-policy-binding \
#   ${var.vm_runtime_sa} \
#   --member="user:natakorn.s@fufonglabs.com" \
#   --role="roles/iam.serviceAccountUser" \
#   --project=${var.gcp_project}

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
