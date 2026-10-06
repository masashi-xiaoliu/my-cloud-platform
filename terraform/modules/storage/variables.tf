variable "project_id" { type = string }
variable "region" { type = string }

variable "name" {
  type    = string
  default = "uploads"
}

variable "force_destroy" {
  type    = bool
  default = true
}

variable "delete_after_days" {
  type    = number
  default = 30
}
