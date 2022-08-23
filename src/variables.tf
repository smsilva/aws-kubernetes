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

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.244.0.0/16"
}

variable "vpc_azs" {
  description = "Availability zones for VPC"
  type        = list(string)

  default = [
    "us-east-1a",
    "us-east-1b",
    "us-east-1c"
  ]
}

variable "vpc_private_subnets" {
  description = "Private subnets for VPC"
  type        = list(string)

  default = [
    "10.244.1.0/24",
    "10.244.2.0/24"
  ]
}

variable "vpc_public_subnets" {
  description = "Public subnets for VPC"
  type        = list(string)

  default = [
    "10.244.101.0/24",
    "10.244.102.0/24"
  ]
}

variable "vpc_enable_nat_gateway" {
  description = "Enable NAT gateway for VPC"
  type        = bool
  default     = true
}

variable "vpc_tags" {
  description = "Tags to apply to resources created by VPC module"
  type        = map(string)
  default = {
    Terraform   = "true"
    Environment = "dev"
  }
}
