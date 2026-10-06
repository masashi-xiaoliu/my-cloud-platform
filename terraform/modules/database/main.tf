# Cloud SQL for PostgreSQL（Case Study CR-2 の本番想定）。
# ⚠ 起動している間ずっと課金される。実験が終わったら enable_database = false で destroy する。
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

resource "google_sql_database_instance" "this" {
  project          = var.project_id
  name             = var.name
  region           = var.region
  database_version = "POSTGRES_16"

  settings {
    # ★ LAB CS-2: tier を上げると性能と料金が上がる
    tier              = var.tier
    edition           = "ENTERPRISE"
    availability_type = "ZONAL"
    disk_size         = 10
    disk_autoresize   = false

    backup_configuration {
      # ★ LAB R05: バックアップを有効にし、復元手順を docs/labs/recovery/README.md の R05 で試す
      enabled    = var.backup_enabled
      start_time = "18:00" # UTC = JST 03:00
    }

    ip_configuration {
      ipv4_enabled = true # 接続は Cloud SQL Auth Proxy 経由。authorized_networks は開けない
    }
  }

  deletion_protection = var.deletion_protection
}

resource "google_sql_database" "app" {
  project  = var.project_id
  name     = "app"
  instance = google_sql_database_instance.this.name
}
