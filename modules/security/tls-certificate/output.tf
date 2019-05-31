output "ca" {
  value = "${tls_self_signed_cert.ca.cert_pem}"
}

output "signed" {
  value = "${tls_locally_signed_cert.signed.cert_pem}"
}
