variable "base_domain" {
  description = "管理画面のホスト名に使うドメイン（ローカルは localtest.me = 127.0.0.1）"
  type        = string
  default     = "localtest.me"
}

variable "ingress_service_type" {
  description = "Traefik Service の type。kind は NodePort、GKE は LoadBalancer"
  type        = string
  default     = "NodePort"

  validation {
    condition     = contains(["NodePort", "LoadBalancer"], var.ingress_service_type)
    error_message = "NodePort か LoadBalancer を指定してください。"
  }
}

variable "expose_admin_uis" {
  description = "Argo CD / Grafana / Prometheus を Ingress で公開するか。クラウドでは false（port-forward で見る）"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  type    = bool
  default = true
}

variable "enable_monitoring" {
  description = "★ LAB TF-03: true にして plan すると、Prometheus/Grafana 一式が追加される差分が見える"
  type        = bool
  default     = false
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
  default   = "admin-change-me"
}

variable "monitoring_values_file" {
  description = "kube-prometheus-stack に追加で渡す values ファイル"
  type        = string
}

variable "argocd_reconciliation_timeout" {
  type    = string
  default = "60s"
}

variable "chart_versions" {
  description = "★ LAB TF-05: null = 最新。動作確認できたらバージョンを固定（pin）して plan の差分を見る"
  type = object({
    traefik               = optional(string)
    argocd                = optional(string)
    metrics_server        = optional(string)
    kube_prometheus_stack = optional(string)
  })
  default = {}
}
