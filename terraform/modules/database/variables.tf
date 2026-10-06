variable "project_id" { type = string }
variable "region" { type = string }

variable "name" {
  type    = string
  default = "mcp-postgres"
}

variable "tier" {
  type    = string
  default = "db-f1-micro"
}

variable "backup_enabled" {
  type    = bool
  default = true
}

variable "deletion_protection" {
  type    = bool
  default = false
}
