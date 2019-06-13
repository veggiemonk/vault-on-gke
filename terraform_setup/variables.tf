variable "service_account_iam_roles" {
  type = "list"

  default = [
    # "roles/logging.logWriter",
    # "roles/monitoring.metricWriter",
    # "roles/monitoring.viewer",
    "roles/viewer"
  ]
}

//roles/container.clusterAdmin

variable "project_id" {
    type = "string"
    default = "vault-dev-242607"
}

variable "project_services" {
  type = "list"

  default = [
    "cloudbuild.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "container.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "storage-component.googleapis.com",
  ]
}