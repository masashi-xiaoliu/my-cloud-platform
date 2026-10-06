variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "zone" {
  type    = string
  default = "asia-northeast1-a"
}

variable "billing_account_id" {
  description = "予算アラート用（空なら作らない）。`gcloud billing accounts list` で確認"
  type        = string
  default     = ""
}

variable "monthly_budget" {
  type    = number
  default = 3000
}

variable "subnet_cidr" {
  description = "★ LAB G03"
  type        = string
  default     = "10.10.0.0/20"
}

variable "node_count" {
  description = "★ LAB G01"
  type        = number
  default     = 1
}

variable "machine_type" {
  description = "★ LAB G02"
  type        = string
  default     = "e2-medium"
}

variable "spot" {
  description = "★ LAB G07"
  type        = bool
  default     = true
}

variable "private_nodes" {
  description = "★ LAB G05: true にすると Cloud NAT も作られる（課金対象）"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  type    = bool
  default = false
}

variable "enable_database" {
  description = "Case Study CR-2（Cloud SQL・課金対象）"
  type        = bool
  default     = false
}

variable "enable_storage" {
  description = "Case Study CR-3（GCS）"
  type        = bool
  default     = false
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
  default   = "admin-change-me"
}

variable "github_repository" {
  description = "例: your-name/my-cloud-platform（空なら WIF を作らない）"
  type        = string
  default     = ""
}
