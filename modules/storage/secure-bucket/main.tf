# Create the storage bucket
resource "google_storage_bucket" "storage" {
  name          = "${var.project_id}-${var.name}"
  project       = "${var.project_id}"
  force_destroy = true
  storage_class = "${var.storage_class}"

  versioning {
    enabled = "${var.versioning}"
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      num_newer_versions = 1
    }
  }

  #TODO custom_lables!!!!
  #   depends_on = ["google_project_service.service"]
}

# Grant service account access to the storage bucket
resource "google_storage_bucket_iam_member" "storage-iam" {
  count  = "${length(var.storage_bucket_roles)}"
  bucket = "${google_storage_bucket.vault.name}"
  role   = "${element(var.storage_bucket_roles, count.index)}"
  member = "serviceAccount:${var.service_account_email}"
}
