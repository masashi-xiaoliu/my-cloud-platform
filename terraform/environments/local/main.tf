# Phase 6: ローカル環境（kind + 共通アドオン）を Terraform で構築する。
#
#   cd terraform/environments/local
#   terraform init
#   terraform plan      # ← 何が作られる予定か必ず読む
#   terraform apply
#   terraform output
#
# state はこのディレクトリの terraform.tfstate（.gitignore 済み）に保存される。
terraform {
  required_version = ">= 1.6"
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.6"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}

module "cluster" {
  source             = "../../modules/kind-cluster"
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  worker_count       = var.worker_count
}

provider "helm" {
  kubernetes {
    host                   = module.cluster.endpoint
    client_certificate     = module.cluster.client_certificate
    client_key             = module.cluster.client_key
    cluster_ca_certificate = module.cluster.cluster_ca_certificate
  }
}

module "addons" {
  source                 = "../../modules/platform-addons"
  ingress_service_type   = "NodePort"
  expose_admin_uis       = true
  enable_metrics_server  = true
  enable_monitoring      = var.enable_monitoring
  grafana_admin_password = var.grafana_admin_password
  monitoring_values_file = "${path.module}/../../../monitoring/prometheus/values.yaml"
  chart_versions         = var.chart_versions

  depends_on = [module.cluster]
}
