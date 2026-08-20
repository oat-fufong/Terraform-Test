# Grafana routed by path
# Requires Grafana's own config to know it's served from a subpath
# (GF_SERVER_ROOT_URL including /grafana/, GF_SERVER_SERVE_FROM_SUB_PATH=true)
resource "google_compute_url_map" "app_urlmap" {
  name            = "app-url-map"
  default_service = google_compute_backend_service.app_backend.id

  host_rule {
    hosts        = [local.lb_domain]
    path_matcher = "main"
  }

  path_matcher {
    name            = "main"
    default_service = google_compute_backend_service.app_backend.id

    path_rule {
      paths   = ["/grafana", "/grafana/*"]
      service = google_compute_backend_service.grafana_backend.id
    }
  }
}

locals {
  lb_domain = var.domain_name == "changeme.example.com" ? "${replace(google_compute_global_address.app_ip.address, ".", "-")}.sslip.io" : var.domain_name

  # google_compute_managed_ssl_certificate doesn't support name_prefix, so
  # derive a stable-but-unique name from the domain.
  # Purpose is to trigger a safe create-new-then-destroy on Terraform when
  # "lb_domain" changes, to safely replace SSL Cert.
  cert_name = "app-ssl-cert-${substr(md5(local.lb_domain), 0, 8)}"
}

resource "google_compute_managed_ssl_certificate" "app_cert" {
  name = local.cert_name

  managed {
    domains = [local.lb_domain]
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

resource "google_compute_url_map" "https_redirect" {
  name = "app-https-redirect"

  default_url_redirect {
    https_redirect = true
    host_redirect  = local.lb_domain
    strip_query    = false
  }
}

# Added to test the chain (url map -> backend -> health check -> instance
# group) over plain HTTP against the raw IP, with no domain/cert needed.
resource "google_compute_target_http_proxy" "app_http_proxy" {
  name    = "app-http-proxy"
  url_map = google_compute_url_map.https_redirect.id
}

resource "google_compute_global_forwarding_rule" "app_http" {
  name       = "app-http-forwarding-rule"
  target     = google_compute_target_http_proxy.app_http_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.app_ip.address
}
