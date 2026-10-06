# GKE Standard クラスタ（ゾーン）+ 専用ノードプール
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# ノード用の最小権限サービスアカウント（デフォルトの Compute SA は権限が広すぎる）
resource "google_service_account" "nodes" {
  project      = var.project_id
  account_id   = "${var.name}-nodes"
  display_name = "GKE nodes for ${var.name}"
}

resource "google_project_iam_member" "nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_container_cluster" "this" {
  project = var.project_id
  name    = var.name
  # ★ LAB G06: zone（ゾーンクラスタ）→ region（リージョンクラスタ）にすると可用性は上がるがノード数が 3 倍になる
  location = var.location

  network    = var.network_id
  subnetwork = var.subnet_id

  # デフォルトノードプールは削除し、下の google_container_node_pool で管理する
  remove_default_node_pool = true
  initial_node_count       = 1

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Dataplane V2 (Cilium ベース)。NetworkPolicy が強制される
  datapath_provider = "ADVANCED_DATAPATH"

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  dynamic "private_cluster_config" {
    for_each = var.private_nodes ? [1] : []
    content {
      enable_private_nodes    = true
      enable_private_endpoint = false
      master_ipv4_cidr_block  = "172.16.0.0/28"
    }
  }

  # ★ LAB G08: true にすると terraform destroy が失敗する（本番の誤削除防止）。学習用 dev は false
  deletion_protection = var.deletion_protection
}

resource "google_container_node_pool" "default" {
  project  = var.project_id
  name     = "default"
  location = var.location
  cluster  = google_container_cluster.this.name

  # ★ LAB G01: ノード数。plan で "~ update in-place" になることを確認する
  node_count = var.node_count

  node_config {
    # ★ LAB G02: マシンタイプ。変更するとノードの作り直しが発生する
    machine_type = var.machine_type
    # ★ LAB G07: Spot VM は安いが、いつでも停止されうる（Pod が再スケジュールされる様子を観察できる）
    spot            = var.spot
    disk_size_gb    = 30
    disk_type       = "pd-standard"
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    labels = {
      pool = "default"
    }
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
