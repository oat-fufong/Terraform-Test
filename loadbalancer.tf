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

  # As of the IAP OAuth Admin API deprecation, no brand/client resource is
  # needed - omitting oauth2_client_id/secret makes IAP use a Google-managed
  # OAuth client automatically. https://docs.cloud.google.com/iap/docs/deprecations/migrate-oauth-client
  iap {
    enabled = true
  }
}

# Least-privilege: grants access to just this one backend service, not the
# whole project. Add more entries to var.iap_allowed_members for teammates.
resource "google_iap_web_backend_service_iam_member" "app_access" {
  for_each = toset(var.iap_allowed_members)

  project             = var.gcp_project
  web_backend_service = google_compute_backend_service.app_backend.name
  role                = "roles/iap.httpsResourceAccessor"
  member              = each.value
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

# Separate IAP grant, scoped to just the Grafana backend - not implied by
# app_access above. Same members list for now; can diverge later if Grafana
# access should be narrower than the main app's.
resource "google_iap_web_backend_service_iam_member" "grafana_access" {
  for_each = toset(var.iap_allowed_members)

  project             = var.gcp_project
  web_backend_service = google_compute_backend_service.grafana_backend.name
  role                = "roles/iap.httpsResourceAccessor"
  member              = each.value
}

resource "google_compute_url_map" "app_urlmap" {
  name            = "app-url-map"
  default_service = google_compute_backend_service.app_backend.id

  host_rule {
    hosts        = [local.grafana_domain]
    path_matcher = "grafana"
  }

  path_matcher {
    name            = "grafana"
    default_service = google_compute_backend_service.grafana_backend.id
  }
}

# While var.domain_name is still the placeholder, fall back to sslip.io
# hostnames derived from our own reserved IP - sslip.io's wildcard DNS
# resolves "<ip-with-dashes>.sslip.io" straight back to that IP, so they're
# real, DNS-verifiable domains with zero setup. Once var.domain_name is set
# to a real domain, lb_domain switches to using it automatically - grafana_domain
# would need its own real subdomain (e.g. grafana.yourdomain.com) at that point.
locals {
  lb_domain      = var.domain_name == "changeme.example.com" ? "${replace(google_compute_global_address.app_ip.address, ".", "-")}.sslip.io" : var.domain_name
  grafana_domain = "grafana.${replace(google_compute_global_address.app_ip.address, ".", "-")}.sslip.io"

  # google_compute_managed_ssl_certificate doesn't support name_prefix, so
  # derive a stable-but-unique name from the domains themselves (via a builtin
  # hash function, no extra provider needed). Only changes when either domain
  # changes, so combined with create_before_destroy below, Terraform stands
  # up the new cert and re-points the proxy at it before tearing down the
  # old one - avoiding "resource in use" on replacement.
  cert_name = "app-ssl-cert-${substr(md5("${local.lb_domain}-${local.grafana_domain}"), 0, 8)}"
}

resource "google_compute_managed_ssl_certificate" "app_cert" {
  name = local.cert_name

  managed {
    domains = [local.lb_domain, local.grafana_domain]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_https_proxy" "app_https_proxy" {
  name             = "app-https-proxy"
  url_map          = google_compute_url_map.app_urlmap.id
  ssl_certificates = [google_compute_managed_ssl_certificate.app_cert.id]
}

resource "google_compute_global_address" "app_ip" {
  name = "app-lb-ip"

  # DNS ends up pointed at this IP once a real domain is in use - guard against a plain `terraform destroy`. 
  # To actually remove this resource delete this lifecycle block first, then destroy
  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_global_forwarding_rule" "app_https" {
  name       = "app-https-forwarding-rule"
  target     = google_compute_target_https_proxy.app_https_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.app_ip.address
}

# Added to test the chain (url map -> backend -> health check -> instance
# group) over plain HTTP against the raw IP, with no domain/cert needed.
# Shares the same url_map and IP as the HTTPS path above, and therefore the
# same IAP protection - not an open door, just unencrypted.
resource "google_compute_target_http_proxy" "app_http_proxy" {
  name    = "app-http-proxy"
  url_map = google_compute_url_map.app_urlmap.id
}

resource "google_compute_global_forwarding_rule" "app_http" {
  name       = "app-http-forwarding-rule"
  target     = google_compute_target_http_proxy.app_http_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.app_ip.address
}
