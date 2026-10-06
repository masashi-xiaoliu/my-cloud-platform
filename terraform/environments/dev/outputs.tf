output "get_credentials_command" {
  value = module.gke.get_credentials_command
}

output "artifact_registry_url" {
  value = module.registry.repository_url
}

output "github_actions_variables" {
  description = "GitHub > Settings > Secrets and variables > Actions > Variables に登録する値"
  value = var.github_repository == "" ? null : {
    GCP_PROJECT_ID   = var.project_id
    GCP_WIF_PROVIDER = google_iam_workload_identity_pool_provider.github[0].name
    GCP_SA_EMAIL     = google_service_account.ci[0].email
  }
}

output "cleanup_reminder" {
  value = "⚠ 実験が終わったら: terraform destroy -var=project_id=${var.project_id}"
}
