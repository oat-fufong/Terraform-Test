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

resource "google_compute_url_map" "app_urlmap" {
  name            = "app-url-map"
  default_service = google_compute_backend_service.app_backend.id
}

# While var.domain_name is still the placeholder, fall back to a sslip.io
# hostname derived from our own reserved IP - sslip.io's wildcard DNS
# resolves "<ip-with-dashes>.sslip.io" straight back to that IP, so it's a
# real, DNS-verifiable domain with zero setup. Once var.domain_name is set
# to a real domain, this automatically switches to using it - no other
# change needed.
locals {
  lb_domain = var.domain_name == "changeme.example.com" ? "${replace(google_compute_global_address.app_ip.address, ".", "-")}.sslip.io" : var.domain_name

  # google_compute_managed_ssl_certificate doesn't support name_prefix, so
  # derive a stable-but-unique name from the domain itself (via a builtin
  # hash function, no extra provider needed). Only changes when lb_domain
  # changes, so combined with create_before_destroy below, Terraform stands
  # up the new cert and re-points the proxy at it before tearing down the
  # old one - avoiding "resource in use" on replacement.
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

# Temporary: lets us test the chain (url map -> backend -> health check ->
# instance group) over plain HTTP against the raw IP, with no domain/cert
# needed. Shares the same url_map and IP as the HTTPS path above - nothing
# here needs to change when a real domain shows up, this just stops being
# the only way in. Revisit removing this once IAP web auth is added -
# right now this is a fully open, unauthenticated door.
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
