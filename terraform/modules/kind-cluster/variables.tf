variable "cluster_name" {
  description = "kind クラスタ名"
  type        = string
  default     = "my-cloud-platform"
}

variable "kubernetes_version" {
  description = "kindest/node のタグ（= Kubernetes バージョン）"
  type        = string
  default     = "v1.31.2"
}

variable "worker_count" {
  description = "worker ノード数"
  type        = number
  default     = 1

  validation {
    condition     = var.worker_count >= 0 && var.worker_count <= 4
    error_message = "worker_count は 0〜4 にしてください（ノート PC のメモリを守るため）。"
  }
}

variable "http_port" {
  type    = number
  default = 80
}

variable "https_port" {
  type    = number
  default = 443
}
