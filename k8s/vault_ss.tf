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
          image = "sethvargo/vault-init:1.0.0"

          env {
            name  = "GCS_BUCKET_NAME"
            value = "$${gcs_bucket_name}"
          }

          env {
            name  = "KMS_KEY_ID"
            value = "projects/$${project}/locations/$${kms_region}/keyRings/$${kms_key_ring}/cryptoKeys/$${kms_crypto_key}"
          }

          env {
            name  = "VAULT_ADDR"
            value = "http://127.0.0.1:8200"
          }

          env {
            name  = "VAULT_SECRET_SHARES"
            value = "$${vault_recovery_shares}"
          }

          env {
            name  = "VAULT_SECRET_THRESHOLD"
            value = "$${vault_recovery_threshold}"
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
          image = "$${vault_container}"
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
            value = "api_addr     = \"https://$${load_balancer_ip}\"\ncluster_addr = \"https://$(POD_IP_ADDR):8201\"\n\nlog_level = \"warn\"\n\nui = true\n\nseal \"gcpckms\" {\n  project    = \"$${project}\"\n  region     = \"$${kms_region}\"\n  key_ring   = \"$${kms_key_ring}\"\n  crypto_key = \"$${kms_crypto_key}\"\n}\n\nstorage \"gcs\" {\n  bucket     = \"$${gcs_bucket_name}\"\n  ha_enabled = \"true\"\n}\n\nlistener \"tcp\" {\n  address     = \"127.0.0.1:8200\"\n  tls_disable = \"true\"\n}\n\nlistener \"tcp\" {\n  address       = \"$(POD_IP_ADDR):8200\"\n  tls_cert_file = \"/etc/vault/tls/vault.crt\"\n  tls_key_file  = \"/etc/vault/tls/vault.key\"\n\n  tls_disable_client_certs = true\n}\n"
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

