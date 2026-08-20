resource "google_compute_health_check" "app_hc" {
  name = "app-health-check"

  http_health_check {
    port = var.backend_port
  }
}

resource "google_compute_backend_service" "app_backend" {
  name          = "app-backend-service"
  port_name     = "http"
  protocol      = "HTTP"
  health_checks = [google_compute_health_check.app_hc.id]

  backend {
    group = google_compute_instance_group.app_ig.self_link
  }

  iap {
    enabled = true
  }
}

resource "google_compute_health_check" "grafana_hc" {
  name = "grafana-health-check"

  # Default path "/" redirects unauthenticated requests to /login (302),
  # which GCP's health check treats as unhealthy even though Grafana is
  # fine. /api/health is Grafana's dedicated no-auth endpoint for this.
  http_health_check {
    port         = 3001
    request_path = "/api/health"
  }
}

resource "google_compute_backend_service" "grafana_backend" {
  name          = "grafana-backend-service"
  port_name     = "grafana"
  protocol      = "HTTP"
  health_checks = [google_compute_health_check.grafana_hc.id]

  backend {
    group = google_compute_instance_group.app_ig.self_link
  }

  iap {
    enabled = true
  }
}
