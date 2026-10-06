variable "project_id" { type = string }
variable "name" { type = string }

variable "location" {
  description = "ゾーン（例: asia-northeast1-a）を指定するとゾーンクラスタになる"
  type        = string
}

variable "network_id" { type = string }
variable "subnet_id" { type = string }
variable "pods_range_name" { type = string }
variable "services_range_name" { type = string }

variable "node_count" {
  type    = number
  default = 1
}

variable "machine_type" {
  type    = string
  default = "e2-medium"
}

variable "spot" {
  type    = bool
  default = true
}

variable "private_nodes" {
  type    = bool
  default = false
}

variable "deletion_protection" {
  type    = bool
  default = false
}
