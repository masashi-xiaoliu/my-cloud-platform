# Phase 7: GCP dev 環境。
#   ⚠ apply した瞬間から課金が始まる。実験が終わったら必ず `terraform destroy`（docs/phases/phase-07-gcp.md）
#
#   terraform init -backend-config="bucket=<PROJECT_ID>-tfstate"
#   terraform plan  -var="project_id=<PROJECT_ID>"
#   terraform apply -var="project_id=<PROJECT_ID>"
terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
  # state は GCS に保存（チーム共有・ロック）。bucket は init 時に -backend-config で渡す
  backend "gcs" {
    prefix = "env/dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  name = "mcp-dev"
  apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "billingbudgets.googleapis.com",
    "sqladmin.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each           = toset(local.apis)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

data "google_project" "this" {
  project_id = var.project_id
}

module "budget" {
  count              = var.billing_account_id == "" ? 0 : 1
  source             = "../../modules/budget"
  billing_account_id = var.billing_account_id
  project_id         = var.project_id
  project_number     = data.google_project.this.number
  monthly_budget     = var.monthly_budget
}

module "network" {
  source      = "../../modules/network"
  project_id  = var.project_id
  region      = var.region
  name        = local.name
  subnet_cidr = var.subnet_cidr
  enable_nat  = var.private_nodes
  depends_on  = [google_project_service.apis]
}

module "registry" {
  source     = "../../modules/artifact-registry"
  project_id = var.project_id
  region     = var.region
  depends_on = [google_project_service.apis]
}

module "gke" {
  source              = "../../modules/gke"
  project_id          = var.project_id
  name                = local.name
  location            = var.zone
  network_id          = module.network.network_id
  subnet_id           = module.network.subnet_id
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name
  node_count          = var.node_count
  machine_type        = var.machine_type
  spot                = var.spot
  private_nodes       = var.private_nodes
  deletion_protection = false
}

module "database" {
  count      = var.enable_database ? 1 : 0
  source     = "../../modules/database"
  project_id = var.project_id
  region     = var.region
  name       = "${local.name}-pg"
  depends_on = [google_project_service.apis]
}

module "storage" {
  count      = var.enable_storage ? 1 : 0
  source     = "../../modules/storage"
  project_id = var.project_id
  region     = var.region
  name       = "${local.name}-uploads"
}

# ---------------- cluster add-ons（ローカルと同じモジュール = 80% 共通） ----------------
data "google_client_config" "this" {}

provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.endpoint}"
    token                  = data.google_client_config.this.access_token
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  }
}

module "addons" {
  source                 = "../../modules/platform-addons"
  ingress_service_type   = "LoadBalancer" # ⚠ L4 ロードバランサが作られる（課金対象）
  expose_admin_uis       = false          # 管理画面はインターネットに出さない
  enable_metrics_server  = false          # GKE は標準搭載
  enable_monitoring      = var.enable_monitoring
  grafana_admin_password = var.grafana_admin_password
  monitoring_values_file = "${path.module}/../../../monitoring/prometheus/values.yaml"
  depends_on             = [module.gke]
}
