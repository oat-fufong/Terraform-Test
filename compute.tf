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
}

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
