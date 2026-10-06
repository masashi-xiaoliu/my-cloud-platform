# Cloud Storage バケット（Case Study CR-3「ファイルアップロード」）
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

resource "google_storage_bucket" "uploads" {
  project                     = var.project_id
  name                        = "${var.project_id}-${var.name}"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  # ★ LAB G10: false だと中身が残っているバケットは destroy できない（データ保護）
  force_destroy = var.force_destroy

  lifecycle_rule {
    condition {
      # ★ LAB G10: 何日でオブジェクトを自動削除するか
      age = var.delete_after_days
    }
    action {
      type = "Delete"
    }
  }
}
