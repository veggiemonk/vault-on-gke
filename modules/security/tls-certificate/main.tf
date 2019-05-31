resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm   = "${tls_private_key.ca.algorithm}"
  private_key_pem = "${tls_private_key.ca.private_key_pem}"

  subject {
    common_name  = "ca.local"
    organization = "HashiCorp Vault"
  }

  validity_period_hours = "${var.validity_period_hours}"
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "digital_signature",
    "key_encipherment",
  ]

  provisioner "local-exec" {
    command = "echo '${self.cert_pem}' > ${var.path_cert_dir}/ca.pem && chmod 0600 ${var.path_cert_dir}/ca.pem"
  }
}

# Create the server certificates
resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

# Create the request to sign the cert with our CA
resource "tls_cert_request" "csr" {
  key_algorithm   = "${tls_private_key.server.algorithm}"
  private_key_pem = "${tls_private_key.server.private_key_pem}"

  dns_names = "${var.dns_names}"

  ip_addresses = "${var.ip_addresses}"

  subject {
    common_name  = "vault.local"
    organization = "HashiCorp Vault"
  }
}

# Now sign the cert
resource "tls_locally_signed_cert" "signed" {
  cert_request_pem = "${tls_cert_request.csr.cert_request_pem}"

  ca_key_algorithm   = "${tls_private_key.ca.algorithm}"
  ca_private_key_pem = "${tls_private_key.ca.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.cert_pem}"

  validity_period_hours = "${var.validity_period_hours}"

  allowed_uses = [
    "cert_signing",
    "client_auth",
    "digital_signature",
    "key_encipherment",
    "server_auth",
  ]

  provisioner "local-exec" {
    command = "echo '${self.cert_pem}' > ${var.path_cert_dir}/vault.pem && echo '${tls_self_signed_cert.ca.cert_pem}' >> ${var.path_cert_dir}/vault.pem && chmod 0600 ${var.path_cert_dir}/vault.pem"
  }
}
