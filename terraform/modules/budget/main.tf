# 予算アラート: 想定以上の課金に早く気付くための安全装置（GCP Phase の最初に作る）
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

resource "google_billing_budget" "this" {
  billing_account = var.billing_account_id
  display_name    = "my-cloud-platform-${var.project_id}"

  budget_filter {
    projects = ["projects/${var.project_number}"]
  }

  amount {
    specified_amount {
      currency_code = var.currency
      # ★ LAB G00: 月の予算額
      units = tostring(var.monthly_budget)
    }
  }

  dynamic "threshold_rules" {
    for_each = [0.5, 0.9, 1.0]
    content {
      threshold_percent = threshold_rules.value
    }
  }
}
