# prod 環境の定義（学習では apply しない想定。dev との「差分」を読むための教材）。
#
# dev との違い:
#   - deletion_protection = true（誤 destroy 防止）
#   - private_nodes = true + Cloud NAT（ノードに外部 IP を持たせない）
#   - spot = false（本番は停止されうる Spot VM を避ける）
#   - node_count 2 以上（ノード障害時も Pod を退避できる）
#   - Cloud SQL を常時有効、バックアップ有効、deletion_protection
#
# `terraform plan` だけ実行して、何が作られる予定か読む演習に使う（Terraform Lab TF-08）。
terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
  backend "gcs" {
    prefix = "env/prod"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "network" {
  source      = "../../modules/network"
  project_id  = var.project_id
  region      = var.region
  name        = "mcp-prod"
  subnet_cidr = "10.110.0.0/20"
  pods_cidr   = "10.120.0.0/16"
  enable_nat  = true
}

module "registry" {
  source     = "../../modules/artifact-registry"
  project_id = var.project_id
  region     = var.region
  keep_count = 30
}

module "gke" {
  source              = "../../modules/gke"
  project_id          = var.project_id
  name                = "mcp-prod"
  location            = var.zone
  network_id          = module.network.network_id
  subnet_id           = module.network.subnet_id
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name
  node_count          = 2
  machine_type        = "e2-standard-2"
  spot                = false
  private_nodes       = true
  deletion_protection = true
}

module "database" {
  source              = "../../modules/database"
  project_id          = var.project_id
  region              = var.region
  name                = "mcp-prod-pg"
  tier                = "db-custom-1-3840"
  deletion_protection = true
}
