output "urls" {
  description = "各管理画面の URL（expose_admin_uis = true の場合）"
  value = var.expose_admin_uis ? {
    argocd     = "http://${local.admin_hosts.argocd}"
    grafana    = var.enable_monitoring ? "http://${local.admin_hosts.grafana}" : "(enable_monitoring = false)"
    prometheus = var.enable_monitoring ? "http://${local.admin_hosts.prometheus}" : "(enable_monitoring = false)"
  } : { note = "port-forward で接続してください（docs/phases/phase-07-gcp.md）" }
}
