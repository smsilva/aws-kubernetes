variable "namespace" {
  type    = string
  default = "external-secrets"
}

variable "service_account_name" {
  type    = string
  default = "secretsmanager-access"
}

variable "iam_policy_name" {
  type = string
}

variable "iam_role_base_name" {
  type    = string
  default = "external-secrets-operator"
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider" {
  type = string
}

variable "cluster_name" {
  type = string
}
