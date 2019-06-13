resource "google_storage_bucket" "backend" {
  name     = "terraform-vault-dev-backend"
  project  = "${var.project_id}"
  location = "EU"
  storage_class = "MULTI_REGIONAL"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      num_newer_versions = 1
    }
  }
}


# # Create the vault service account
# resource "google_service_account" "terraform-sa" {
#   account_id   = "terraform-sa"
#   display_name = "Terraform pipeline"
#   project      = "${var.project_id}"
# }

# # Create a service account key
# resource "google_service_account_key" "terraform" {
#   service_account_id = "${google_service_account.terraform-sa.name}"
# }

# # Add the service account to the project
# resource "google_project_iam_member" "service-account" {
#   count   = "${length(var.service_account_iam_roles)}"
#   project = "${var.project_id}"
#   role    = "${element(var.service_account_iam_roles, count.index)}"
#   member  = "serviceAccount:${google_service_account.terraform-sa.email}"
# }


# # Enable required services on the project
# resource "google_project_service" "service" {
#   count   = "${length(var.project_services)}"
#   project = "${var.project_id}"
#   service = "${element(var.project_services, count.index)}"

#   # Do not disable the service on destroy. On destroy, we are going to
#   # destroy the project, but we need the APIs available to destroy the
#   # underlying resources.
#   disable_on_destroy = false
# }

# # Add user-specified roles
# resource "google_project_iam_member" "service-account-custom" {
#   count   = "${length(var.service_account_custom_iam_roles)}"
#   project = "${var.project_id}"
#   role    = "${element(var.service_account_custom_iam_roles, count.index)}"
#   member  = "serviceAccount:${google_service_account.terraform-sa.email}"
# }

# #------------------------------------------------------------------------------
# # Generate a random suffix for the KMS keyring. Like projects, key rings names
# # must be globally unique within the project. A key ring also cannot be
# # destroyed, so deleting and re-creating a key ring will fail.
# #
# # This uses a random_id to prevent that from happening.
# resource "random_id" "kms_random" {
#   prefix      = "${var.kms_key_ring_prefix}"
#   byte_length = "8"
# }

# # Obtain the key ring ID or use a randomly generated on.
# locals {
#   kms_key_ring = "${var.kms_key_ring != "" ? var.kms_key_ring : random_id.kms_random.hex}"
# }

# # Create the KMS key ring
# resource "google_kms_key_ring" "vault" {
#   name     = "${local.kms_key_ring}"
#   location = "${var.region}"
#   project  = "${var.project_id}"

#   depends_on = ["google_project_service.service"]
# }

# # Create the crypto key for encrypting init keys
# resource "google_kms_crypto_key" "vault-init" {
#   name            = "${var.kms_crypto_key}"
#   key_ring        = "${google_kms_key_ring.vault.id}"
#   rotation_period = "604800s"
# }

# resource "google_kms_crypto_key_iam_member" "vault-init" {
#   crypto_key_id = "${google_kms_crypto_key.vault-init.id}"
#   # role          = "projects/${var.project_id}/roles/${google_project_iam_custom_role.vault-seal-kms.role_id}"
#   role          = "projects/${var.project_id}/roles/roles/cloudkms.cryptoKeyEncrypterDecryptor"
#   member        = "serviceAccount:${google_service_account.terraform-sa.email}"
# }