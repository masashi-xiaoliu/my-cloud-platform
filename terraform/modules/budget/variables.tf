variable "billing_account_id" { type = string }
variable "project_id" { type = string }
variable "project_number" { type = string }

variable "currency" {
  type    = string
  default = "JPY"
}

variable "monthly_budget" {
  type    = number
  default = 3000
}
