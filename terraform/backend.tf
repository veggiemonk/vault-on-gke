terraform {
  backend "gcs" {
    bucket = "terraform-vault-dev-backend"
    prefix = "vault-dev/state"

    # credentials = "/workspace/service_account_key.json"
  }
}
