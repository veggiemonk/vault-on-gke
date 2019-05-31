variable "name" {
  description = "name of the bucket. It will be prefixed by the projectID"
  type        = "string"
}

variable "project_id" {
  description = "ID of the GCP project"
  type        = "string"
}

variable "storage_bucket_roles" {
  description = "TODO"
  type        = "list"
}

variable "service_account_email" {
  description = "The email of the service account to assign the roles to"
  type        = "string"
}

// --------------------------------------------------------
// OPTIONAL
// --------------------------------------------------------
variable "versioning" {
  description = "Enables the versioning for the bucket"
  default     = true
}

variable "storage_class" {
  description = "TODO"
  type        = "string"
  default     = "MULTI_REGIONAL"
}

variable "custom_labels" {
  description = "A map of custom labels to apply to the resources. The key is the label name and the value is the label value."
  type        = "map"
  default     = {}
}
