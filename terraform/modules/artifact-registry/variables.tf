variable "project_id" { type = string }
variable "region" { type = string }

variable "repository_id" {
  type    = string
  default = "mcp"
}

variable "keep_count" {
  type    = number
  default = 10
}
