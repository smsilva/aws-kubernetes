resource "random_string" "id" {
  length      = 6
  min_lower   = 3
  min_numeric = 3
  lower       = true
  special     = false
}

variable "vpc_name" {
  description = "Name of VPC"
  type        = string
  default     = "example-vpc"
}
