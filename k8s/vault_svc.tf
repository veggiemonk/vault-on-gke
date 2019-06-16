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
    load_balancer_ip        = "$${load_balancer_ip}"
    external_traffic_policy = "Local"
  }
}

