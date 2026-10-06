variable "cluster_name" {
  type    = string
  default = "my-cloud-platform"
}

variable "kubernetes_version" {
  type    = string
  default = "v1.31.2"
}

variable "worker_count" {
  description = "★ LAB TF-01"
  type        = number
  default     = 1
}

variable "enable_monitoring" {
  description = "★ LAB TF-03 / Phase 8: true にすると Prometheus + Grafana が入る"
  type        = bool
  default     = false
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
  default   = "admin-change-me"
}

variable "chart_versions" {
  description = "★ LAB TF-05"
  type = object({
    traefik               = optional(string)
    argocd                = optional(string)
    metrics_server        = optional(string)
    kube_prometheus_stack = optional(string)
  })
  default = {}
}
