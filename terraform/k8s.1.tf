# Query the client configuration for our current service account, which shoudl
# have permission to talk to the GKE cluster since it created it.
data "google_client_config" "current" {}

# This file contains all the interactions with Kubernetes
provider "kubernetes" {
  load_config_file = false
  host             = "${google_container_cluster.vault.endpoint}"

  cluster_ca_certificate = "${base64decode(google_container_cluster.vault.master_auth.0.cluster_ca_certificate)}"
  token                  = "${data.google_client_config.current.access_token}"
}

# Write the secret
resource "kubernetes_secret" "vault-tls" {
  metadata {
    name = "vault-tls"
  }

  data {
    "vault.crt" = "${tls_locally_signed_cert.vault.cert_pem}\n${tls_self_signed_cert.vault-ca.cert_pem}"
    "vault.key" = "${tls_private_key.vault.private_key_pem}"
    "ca.crt"    = "${tls_self_signed_cert.vault-ca.cert_pem}"
  }
}

# Render the YAML file
data "template_file" "vault" {
  template = "${file("${path.module}/../k8s/vault.yaml")}"

  vars {
    load_balancer_ip         = "${google_compute_address.vault.address}"
    num_vault_pods           = "${var.num_vault_pods}"
    vault_container          = "${var.vault_container}"
    vault_init_container     = "${var.vault_init_container}"
    vault_recovery_shares    = "${var.vault_recovery_shares}"
    vault_recovery_threshold = "${var.vault_recovery_threshold}"

    project = "${google_kms_key_ring.vault.project}"

    kms_region     = "${google_kms_key_ring.vault.location}"
    kms_key_ring   = "${google_kms_key_ring.vault.name}"
    kms_crypto_key = "${google_kms_crypto_key.vault-init.name}"

    gcs_bucket_name = "${google_storage_bucket.vault.name}"
  }
}


resource "kubernetes_service" "vault" {
  metadata {
    name = "vault"

    labels {
      app = "vault"
    }
  }

  spec {
    port {
      name        = "vault-port"
      protocol    = "TCP"
      port        = 443
      target_port = "8200"
    }

    selector {
      app = "vault"
    }

    type                    = "LoadBalancer"
    load_balancer_ip        = "${google_compute_address.vault.address}"
    external_traffic_policy = "Local"
  }
}

data template vault_config {
  
}

resource "kubernetes_stateful_set" "vault" {
  metadata {
    name = "vault"

    labels {
      app = "vault"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels {
        app = "vault"
      }
    }

    template {
      metadata {
        labels {
          app = "vault"
        }
      }

      spec {
        volume {
          name = "vault-tls"

          secret {
            secret_name = "vault-tls"
          }
        }

        container {
          name  = "vault-init"
          image = "${var.vault_init_container}"

          env {
            name  = "GCS_BUCKET_NAME"
            value = "${google_storage_bucket.vault.name}"
          }

          env {
            name  = "KMS_KEY_ID"
            value = "projects/${google_kms_key_ring.vault.project}/locations/${google_kms_key_ring.vault.location}/keyRings/${google_kms_key_ring.vault.name}/cryptoKeys/${google_kms_crypto_key.vault-init.name}"
          }

          env {
            name  = "VAULT_ADDR"
            value = "http://127.0.0.1:8200"
          }

          env {
            name  = "VAULT_SECRET_SHARES"
            value = "${var.vault_recovery_shares}"
          }

          env {
            name  = "VAULT_SECRET_THRESHOLD"
            value = "${var.vault_recovery_threshold}"
          }

          resources {
            requests {
              cpu    = "100m"
              memory = "64Mi"
            }
          }

          image_pull_policy = "IfNotPresent"
        }

        container {
          name  = "vault"
          image = "${var.vault_container}"
          args  = ["server"]

          port {
            name           = "vault-port"
            container_port = 8200
            protocol       = "TCP"
          }

          port {
            name           = "cluster-port"
            container_port = 8201
            protocol       = "TCP"
          }

          env {
            name  = "VAULT_ADDR"
            value = "http://127.0.0.1:8200"
          }

          env {
            name = "POD_IP_ADDR"

            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }

          env {
            name  = "VAULT_LOCAL_CONFIG"
            value = "api_addr     = \"https://${google_compute_address.vault.address}\"\ncluster_addr = \"https://$(POD_IP_ADDR):8201\"\n\nlog_level = \"warn\"\n\nui = true\n\nseal \"gcpckms\" {\n  project    = \"${google_kms_key_ring.vault.project}\"\n  region     = \"$${kms_region}\"\n  key_ring   = \"$${kms_key_ring}\"\n  crypto_key = \"$${kms_crypto_key}\"\n}\n\nstorage \"gcs\" {\n  bucket     = \"$${gcs_bucket_name}\"\n  ha_enabled = \"true\"\n}\n\nlistener \"tcp\" {\n  address     = \"127.0.0.1:8200\"\n  tls_disable = \"true\"\n}\n\nlistener \"tcp\" {\n  address       = \"$(POD_IP_ADDR):8200\"\n  tls_cert_file = \"/etc/vault/tls/vault.crt\"\n  tls_key_file  = \"/etc/vault/tls/vault.key\"\n\n  tls_disable_client_certs = true\n}\n"
          }

          resources {
            requests {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          volume_mount {
            name       = "vault-tls"
            mount_path = "/etc/vault/tls"
          }

          readiness_probe {
            http_get {
              path   = "/v1/sys/health?standbyok=true"
              port   = "8200"
              scheme = "HTTPS"
            }

            initial_delay_seconds = 5
            period_seconds        = 5
          }

          image_pull_policy = "IfNotPresent"

          security_context {
            capability {
              add = ["IPC_LOCK"]
            }
          }
        }

        termination_grace_period_seconds = 10

        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 60

              pod_affinity_term {
                label_selector {
                  match_expression {
                    key      = "app"
                    operator = "In"
                    values   = ["vault"]
                  }
                }

                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }
      }
    }

    service_name = "vault"
  }
}



# Build the URL for the keys on GCS
data "google_storage_object_signed_url" "keys" {
  bucket = "${google_storage_bucket.vault.name}"
  path   = "root-token.enc"

  credentials = "${base64decode(google_service_account_key.vault.private_key)}"

  depends_on = ["null_resource.wait-for-finish"]
}

# Download the encrypted recovery unseal keys and initial root token from GCS
data "http" "keys" {
  url = "${data.google_storage_object_signed_url.keys.signed_url}"
}

# Decrypt the values
data "google_kms_secret" "keys" {
  crypto_key = "${google_kms_crypto_key.vault-init.id}"
  ciphertext = "${data.http.keys.body}"
}

# Output the initial root token
output "root_token" {
  value = "${data.google_kms_secret.keys.plaintext}"
}

# Uncomment this if you want to decrypt the token yourself
# output "root_token_decrypt_command" {
#   value = "gsutil cat gs://${google_storage_bucket.vault.name}/root-token.enc | base64 --decode | gcloud kms decrypt --project ${local.vault_project_id} --location ${var.region} --keyring ${google_kms_key_ring.vault.name} --key ${google_kms_crypto_key.vault-init.name} --ciphertext-file - --plaintext-file -"
# }

