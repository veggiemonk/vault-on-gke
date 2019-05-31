variable "path_cert_dir" {
  description = "Directory to output the certificates"
  type        = "string"
  default     = "tls"
}

variable "subject_name" {
  description = "Common name"
}

variable "validity_period_hours" {
  description = "Validity of the certificate in hours"
  default     = 8760
}

variable "ip_addresses" {
  description = "List of IP"
  type        = "list"
  default     = []
}

variable "dns_names" {
  description = "List of DNS entries for the certificates"
  type        = "list"
  default     = []
}
