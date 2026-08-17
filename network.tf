resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
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

# Lets you reach Grafana (and other debug-only ports) via IAP tunnel,
# same pattern as SSH - not exposed through the load balancer at all.
resource "google_compute_firewall" "allow_iap_debug_ports" {
  name    = "allow-debug-ports-from-iap"
  network = google_compute_network.vpc_network.name

  source_ranges = [var.iap_forwarding_cidr]

  allow {
    protocol = "tcp"
    ports    = ["3001"] # grafana
  }
}

# Only Google's LB health-check ranges may reach the backend port.
resource "google_compute_firewall" "allow_lb_health_check" {
  name    = "allow-lb-health-check"
  network = google_compute_network.vpc_network.name

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["lb-backend"]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.backend_port), "3001"]
  }
}
