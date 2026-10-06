variable "project_id" { type = string }
variable "region" { type = string }

variable "name" {
  type    = string
  default = "mcp"
}

variable "subnet_cidr" {
  type    = string
  default = "10.10.0.0/20"
}

variable "pods_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "services_cidr" {
  type    = string
  default = "10.30.0.0/20"
}

variable "allow_iap_ssh" {
  type    = bool
  default = true
}

variable "enable_nat" {
  type    = bool
  default = false
}
