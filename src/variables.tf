resource "random_string" "id" {
  length      = 6
  min_lower   = 3
  min_numeric = 3
  lower       = true
  special     = false
}

variable "cluster_name" {
  type    = string
  default = "wasp-sandbox-example"
}

variable "region" {
  type    = string
  default = "us-east-1"
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

variable "vpc_intra_subnets" {
  description = "Intra subnets for VPC"
  type        = list(string)

  default = [
    "10.244.52.0/24",
    "10.244.53.0/24",
    "10.244.54.0/24",
  ]
}

variable "vpc_private_subnets" {
  description = "Private subnets for VPC"
  type        = list(string)

  default = [
    "10.244.0.0/20",
    "10.244.16.0/20",
    "10.244.32.0/20",
  ]
}

variable "vpc_public_subnets" {
  description = "Public subnets for VPC"
  type        = list(string)

  default = [
    "10.244.48.0/24",
    "10.244.49.0/24",
    "10.244.50.0/24",
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
    Terraform = "true"
  }
}
