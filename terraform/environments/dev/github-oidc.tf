# GitHub Actions → GCP を「鍵ファイルなし」で認証する Workload Identity Federation。
# サービスアカウントキー（JSON）を GitHub Secrets に置かないのがポイント（docs/adr/0007）。
resource "google_iam_workload_identity_pool" "github" {
  count                     = var.github_repository == "" ? 0 : 1
  project                   = var.project_id
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  depends_on                = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  count                              = var.github_repository == "" ? 0 : 1
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }
  # このリポジトリ以外からのトークンは拒否
  attribute_condition = "assertion.repository == \"${var.github_repository}\""
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "ci" {
  count        = var.github_repository == "" ? 0 : 1
  project      = var.project_id
  account_id   = "github-actions"
  display_name = "GitHub Actions (plan / image push)"
}

resource "google_project_iam_member" "ci" {
  for_each = var.github_repository == "" ? toset([]) : toset([
    "roles/viewer",                  # terraform plan 用（読み取りのみ）
    "roles/artifactregistry.writer", # イメージ push 用
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.ci[0].email}"
}

resource "google_service_account_iam_member" "ci_wif" {
  count              = var.github_repository == "" ? 0 : 1
  service_account_id = google_service_account.ci[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github[0].name}/attribute.repository/${var.github_repository}"
}
